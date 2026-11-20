/*
-------------------------------------------------------------------------------
Name:     Sources/toc/WindowServerService.swift
Purpose:  Lectura de ventanas directamente de WindowServer (CGWindowList), que
          sigue respondiendo bien cuando Accesibilidad falla tras el reposo.
          Solo lee: WindowServer no permite mover ventanas de otras apps.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import CoreGraphics

/// Ventana tal como la ve WindowServer.
struct ServerWindow {
    let id: CGWindowID
    let pid: pid_t
    let bounds: CGRect
}

enum WindowServerService {

    /**
     * @brief  Devuelve las ventanas normales en pantalla, de delante hacia atrás.
     *
     * @return Ventanas de capa 0 con su dueño y su marco (origen arriba a la izquierda).
     */
    static func onScreenWindows() -> [ServerWindow] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let id = info[kCGWindowNumber as String] as? Int,
                  let pid = info[kCGWindowOwnerPID as String] as? Int,
                  let dict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: dict as CFDictionary) else {
                return nil
            }
            return ServerWindow(id: CGWindowID(id), pid: pid_t(pid), bounds: bounds)
        }
    }

    /**
     * @brief  Devuelve la ventana de delante de un proceso.
     *
     * @param[in]  pid  Identificador del proceso.
     * @return La primera ventana del proceso en el orden de WindowServer, o nil.
     */
    static func frontWindow(pid: pid_t) -> ServerWindow? {
        onScreenWindows().first { $0.pid == pid }
    }

    /**
     * @brief  Devuelve la ventana normal que está más arriba en un punto de la pantalla.
     *
     * @param[in]  point    Punto global (origen arriba a la izquierda).
     * @param[in]  exclude  Proceso que se ignora (normalmente, el propio toc).
     * @return La ventana encontrada, o nil.
     */
    static func window(at point: CGPoint, excluding exclude: pid_t) -> ServerWindow? {
        onScreenWindows().first { $0.pid != exclude && $0.bounds.contains(point) }
    }

    /**
     * @brief  Lee el marco actual de una ventana concreta.
     *
     * @param[in]  id  CGWindowID de la ventana.
     * @return Marco con origen arriba a la izquierda, o nil si ya no existe.
     */
    static func bounds(of id: CGWindowID) -> CGRect? {
        guard let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]],
              let dict = list.first?[kCGWindowBounds as String] as? [String: Any] else {
            return nil
        }
        return CGRect(dictionaryRepresentation: dict as CFDictionary)
    }
}
