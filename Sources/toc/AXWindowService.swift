/*
-------------------------------------------------------------------------------
Name:     Sources/toc/AXWindowService.swift
Purpose:  Acceso a las ventanas de otras apps mediante la API de
          Accesibilidad. Pide los elementos de nuevo en cada acción (nunca
          guarda referencias entre reposos), conserva el código de error de
          cada llamada y comprueba que la ventana se ha movido de verdad.
Version:  v0.0.3
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit
import ApplicationServices
import TocCore

/// Función privada de HIServices que relaciona un AXUIElement con su CGWindowID.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Motivo por el que no se pudo obtener la ventana activa con AX.
enum AXWindowFailure: Error, CustomStringConvertible {
    case permissionMissing
    case brokenTree
    case noWindow(AXError)

    var description: String {
        switch self {
        case .permissionMissing: "toc no tiene permiso de Accesibilidad"
        case .brokenTree: "macOS devuelve la app en lugar de sus ventanas (fallo tras el reposo)"
        case .noWindow(let error): "la app no tiene ventana activa (AXError \(error.rawValue))"
        }
    }
}

@MainActor
enum AXWindowService {

    /// Tiempo máximo de espera por llamada AX, para no bloquear toc si la app no responde.
    static let messagingTimeout: Float = 1.0

    /**
     * @brief  Lee un atributo AX.
     *
     * @param[in]  element    Elemento AX.
     * @param[in]  attribute  Nombre del atributo.
     * @return Par con el valor (o nil) y el código de error.
     */
    static func attribute(_ element: AXUIElement, _ attribute: String) -> (CFTypeRef?, AXError) {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return (value, error)
    }

    /**
     * @brief  Devuelve el rol de un elemento AX.
     *
     * @param[in]  element  Elemento AX.
     * @return Rol (por ejemplo "AXWindow"), o nil si no se puede leer.
     */
    static func role(_ element: AXUIElement) -> String? {
        attribute(element, kAXRoleAttribute).0 as? String
    }

    /**
     * @brief  Convierte un CFTypeRef en AXUIElement si lo es.
     *
     * @param[in]  value  Valor devuelto por AX.
     * @return Elemento AX, o nil si el valor es de otro tipo.
     */
    static func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    /**
     * @brief  Crea el elemento AX de una app con el tiempo máximo de espera configurado.
     *
     * @param[in]  pid  Identificador del proceso.
     * @return Elemento AX de la app.
     */
    static func application(_ pid: pid_t) -> AXUIElement {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, messagingTimeout)
        return app
    }

    /**
     * @brief  Obtiene la ventana activa de una app y comprueba que es una ventana de verdad.
     *
     * Prueba, en este orden, la ventana con foco, la ventana principal y la
     * primera ventana de la lista. Si lo que devuelve AX es la propia app
     * (rol AXApplication), declara el árbol corrupto.
     *
     * @param[in]  pid  Identificador del proceso.
     * @return La ventana, o el motivo del fallo.
     */
    static func focusedWindow(pid: pid_t) -> Result<AXUIElement, AXWindowFailure> {
        let app = application(pid)
        var lastError = AXError.success
        var sawApplicationRole = false
        for attributeName in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            let (value, error) = attribute(app, attributeName)
            if error == .apiDisabled { return .failure(.permissionMissing) }
            lastError = error
            guard let window = element(value) else { continue }
            switch role(window) {
            case kAXWindowRole: return .success(window)
            case kAXApplicationRole: sawApplicationRole = true
            default: continue
            }
        }
        let (list, error) = attribute(app, kAXWindowsAttribute)
        if error == .apiDisabled { return .failure(.permissionMissing) }
        for window in (list as? [AXUIElement]) ?? [] {
            switch role(window) {
            case kAXWindowRole: return .success(window)
            case kAXApplicationRole: sawApplicationRole = true
            default: continue
            }
        }
        return .failure(sawApplicationRole ? .brokenTree : .noWindow(lastError))
    }

    /**
     * @brief  Lee el marco de una ventana.
     *
     * @param[in]  window  Elemento AX de la ventana.
     * @return Marco con origen arriba a la izquierda, o nil si no se puede leer.
     */
    static func frame(_ window: AXUIElement) -> CGRect? {
        var point = CGPoint.zero, size = CGSize.zero
        guard let position = attribute(window, kAXPositionAttribute).0,
              let dimensions = attribute(window, kAXSizeAttribute).0,
              CFGetTypeID(position) == AXValueGetTypeID(),
              CFGetTypeID(dimensions) == AXValueGetTypeID(),
              AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(dimensions as! AXValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: point, size: size)
    }

    /**
     * @brief  Devuelve el CGWindowID de una ventana AX.
     *
     * @param[in]  window  Elemento AX de la ventana.
     * @return Identificador de WindowServer, o nil si no se puede obtener.
     */
    static func windowID(_ window: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        return _AXUIElementGetWindow(window, &id) == .success ? id : nil
    }

    /**
     * @brief  Cambia un atributo de geometría (posición o tamaño).
     *
     * @param[in]  window     Elemento AX de la ventana.
     * @param[in]  attribute  kAXPositionAttribute o kAXSizeAttribute.
     * @param[in]  value      AXValue con el punto o el tamaño.
     * @return Código de error de la llamada.
     */
    @discardableResult
    static func set(_ window: AXUIElement, _ attribute: String, _ value: AXValue) -> AXError {
        AXUIElementSetAttributeValue(window, attribute as CFString, value)
    }

    /**
     * @brief  Mueve y redimensiona una ventana, y devuelve dónde ha quedado.
     *
     * Se aplica tamaño, posición y otra vez tamaño: si la ventana cambia de
     * pantalla, macOS puede limitar el primer tamaño a la pantalla de origen.
     * Durante el cambio se desactiva AXEnhancedUserInterface, que en apps como
     * Chrome o Electron anima el cambio y lo deja a medias.
     *
     * @param[in]  window  Elemento AX de la ventana.
     * @param[in]  pid     Proceso dueño de la ventana.
     * @param[in]  target  Marco de destino con origen arriba a la izquierda.
     * @return Marco leído después del cambio, o nil si no se puede leer.
     */
    static func setFrame(_ window: AXUIElement, pid: pid_t, to target: CGRect) -> CGRect? {
        let app = application(pid)
        let enhanced = attribute(app, "AXEnhancedUserInterface").0 as? Bool ?? false
        if enhanced {
            AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse)
        }
        defer {
            if enhanced {
                AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
            }
        }
        var size = target.size, origin = target.origin
        guard let sizeValue = AXValueCreate(.cgSize, &size),
              let originValue = AXValueCreate(.cgPoint, &origin) else {
            return nil
        }
        set(window, kAXSizeAttribute, sizeValue)
        let positionError = set(window, kAXPositionAttribute, originValue)
        set(window, kAXSizeAttribute, sizeValue)
        if positionError != .success {
            Log.ax.error("Fallo al mover la ventana: AXError \(positionError.rawValue, privacy: .public)")
        }
        return frame(window)
    }

    /**
     * @brief  Observa una app para el detector de salud de Accesibilidad.
     *
     * @param[in]  pid                  Identificador del proceso.
     * @param[in]  windowServerWindows  Ventanas de capa 0 que WindowServer ve para la app.
     * @return Observación con el código de error y los roles devueltos.
     */
    static func observe(pid: pid_t, windowServerWindows: Int) -> AXObservation {
        let (list, error) = attribute(application(pid), kAXWindowsAttribute)
        let roles = ((list as? [AXUIElement]) ?? []).compactMap(role)
        return AXObservation(windowServerWindows: windowServerWindows, error: error.rawValue, roles: roles)
    }
}
