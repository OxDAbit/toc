/*
-------------------------------------------------------------------------------
Name:     Sources/toc/WindowMover.swift
Purpose:  Orquesta cada acción: localiza la ventana activa, elige la pantalla,
          calcula el destino con LayoutEngine y lo aplica por Accesibilidad.
          Si AX falla (por ejemplo, tras el reposo) y la app es scriptable,
          recurre a Apple Events. Guarda el historial para «Restaurar» y
          lleva ventanas a la pantalla siguiente o anterior.
Version:  v0.0.2
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit
import TocCore

/// Resultado de una acción.
enum MoveOutcome {
    /// La ventana se movió; indica por qué vía.
    case moved(via: String)
    /// No se movió por un motivo puntual (sin ventana, sin historial…).
    case notMoved(String)
    /// No se puede mover por el estado de Accesibilidad.
    case unavailable(AXHealth, String)
}

/// Pantalla en coordenadas de Accesibilidad (origen arriba a la izquierda).
struct ScreenInfo {
    let frame: CGRect
    let visible: CGRect

    /**
     * @brief  Devuelve las pantallas conectadas en coordenadas de Accesibilidad.
     *
     * @return Una entrada por pantalla con su marco y su zona útil.
     */
    @MainActor
    static func current() -> [ScreenInfo] {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSScreen.screens.map {
            ScreenInfo(frame: ScreenGeometry.topLeft(fromCocoa: $0.frame, primaryHeight: primaryHeight),
                       visible: ScreenGeometry.topLeft(fromCocoa: $0.visibleFrame, primaryHeight: primaryHeight))
        }
    }
}

/// Motivo por el que una acción no tiene destino.
private struct MoveRefusal: Error {
    let message: String

    /**
     * @brief  Crea el motivo.
     *
     * @param[in]  message  Texto que se registra y se muestra.
     */
    init(_ message: String) { self.message = message }
}

/// Ventana que se va a mover y forma de moverla.
private struct MovableWindow {
    let id: CGWindowID?
    let frame: CGRect
    let via: String
    let apply: (CGRect) -> CGRect?
}

@MainActor
final class WindowMover {

    /// Marco anterior de cada ventana, para «Restaurar».
    private var history: [CGWindowID: CGRect] = [:]

    /**
     * @brief  Ejecuta una acción sobre la ventana activa.
     *
     * @param[in]  action  Acción a ejecutar.
     * @return Resultado de la acción.
     */
    func perform(_ action: WindowAction) -> MoveOutcome {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != getpid() else {
            return .notMoved("no hay ninguna app activa")
        }
        let name = app.localizedName ?? "la app"

        let candidates: [MovableWindow]
        switch resolve(app) {
        case .success(let windows): candidates = windows
        case .failure(.permissionMissing):
            return .unavailable(.permissionMissing, "toc no tiene permiso de Accesibilidad")
        case .failure(.brokenTree):
            return .unavailable(.broken,
                                "macOS ha dejado de dar acceso a las ventanas de \(name) y no es una app scriptable")
        case .failure(let failure):
            return .notMoved("\(name): \(failure)")
        }

        for window in candidates {
            let destination: CGRect
            switch self.destination(for: action, window: window) {
            case .success(let frame): destination = frame
            case .failure(let reason): return .notMoved(reason.message)
            }
            if action != .restore, let id = window.id, history[id] == nil {
                history[id] = window.frame
            }
            let result = window.apply(destination)
            if let result, abs(result.minX - destination.minX) <= 4, abs(result.minY - destination.minY) <= 4 {
                if action == .restore, let id = window.id { history[id] = nil }
                Log.mover.info("\(action.rawValue) en \(name) por \(window.via)")
                return .moved(via: window.via)
            }
            Log.mover.error("\(window.via) no movió \(name) a \(destination.debugDescription); quedó en \(result?.debugDescription ?? "?")")
        }
        return .notMoved("\(name) no ha aceptado la nueva posición")
    }

    /**
     * @brief  Calcula el marco de destino de una acción para una ventana.
     *
     * @param[in]  action  Acción solicitada.
     * @param[in]  window  Ventana a mover.
     * @return Marco de destino, o el motivo por el que no hay ninguno.
     */
    private func destination(for action: WindowAction, window: MovableWindow) -> Result<CGRect, MoveRefusal> {
        if action == .restore {
            guard let frame = window.id.flatMap({ history[$0] }) else {
                return .failure(MoveRefusal("no hay una posición anterior que restaurar"))
            }
            return .success(frame)
        }
        let screens = ScreenInfo.current()
        guard let index = ScreenGeometry.screenIndex(for: window.frame, screens: screens.map(\.frame)) else {
            return .failure(MoveRefusal("no se encuentra la pantalla de la ventana"))
        }
        switch action {
        case .nextDisplay, .previousDisplay:
            let direction: ScreenDirection = action == .nextDisplay ? .next : .previous
            guard let target = ScreenGeometry.adjacentIndex(from: index, screens: screens.map(\.frame),
                                                            direction: direction) else {
                return .failure(MoveRefusal("solo hay una pantalla"))
            }
            return .success(ScreenGeometry.transfer(window.frame, from: screens[index].visible,
                                                    to: screens[target].visible))
        default:
            guard let frame = LayoutEngine.frame(for: action, window: window.frame,
                                                 visible: screens[index].visible) else {
                return .failure(MoveRefusal("la acción no tiene posición de destino"))
            }
            return .success(frame)
        }
    }

    /**
     * @brief  Busca las vías disponibles para mover la ventana activa de una app.
     *
     * Devuelve primero la vía de Accesibilidad y, si la app es scriptable,
     * Apple Events como respaldo. Si AX está roto y la app no es scriptable,
     * devuelve el fallo.
     *
     * @param[in]  app  App activa.
     * @return Vías disponibles en orden de preferencia, o el motivo del fallo.
     */
    private func resolve(_ app: NSRunningApplication) -> Result<[MovableWindow], AXWindowFailure> {
        let pid = app.processIdentifier
        var windows: [MovableWindow] = []
        var axFailure: AXWindowFailure?

        switch AXWindowService.focusedWindow(pid: pid) {
        case .success(let window):
            if let frame = AXWindowService.frame(window) {
                windows.append(MovableWindow(id: AXWindowService.windowID(window), frame: frame,
                                             via: "Accesibilidad") { target in
                    AXWindowService.setFrame(window, pid: pid, to: target)
                })
            } else {
                axFailure = .brokenTree
            }
        case .failure(let failure):
            axFailure = failure
        }

        if case .permissionMissing = axFailure { return .failure(.permissionMissing) }

        if AppleEventsMover.isScriptable(app), let bundleID = app.bundleIdentifier,
           let frame = AppleEventsMover.frame(bundleID: bundleID) {
            let id = WindowServerService.frontWindow(pid: pid)?.id
            windows.append(MovableWindow(id: id, frame: frame, via: "Apple Events") { target in
                AppleEventsMover.setFrame(bundleID: bundleID, to: target)
            })
        }

        if windows.isEmpty {
            return .failure(axFailure ?? .noWindow(.noValue))
        }
        return .success(windows)
    }
}
