/*
-------------------------------------------------------------------------------
Name:     tools/toc-probe/Sources/toc-probe/AXInspector.swift
Purpose:  Envoltorio fino de la API de Accesibilidad (AXUIElement) que, a
          diferencia de Rectangle, conserva el código de error de cada
          llamada y su duración, y lo compara con lo que ve WindowServer.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit
import ApplicationServices

/// Función privada de HIServices que Rectangle y otros gestores de ventanas
/// usan para relacionar un AXUIElement con su CGWindowID.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Función privada de HIServices que crea un AXUIElement a partir de un token
/// remoto (pid + identificador interno). La usan gestores como AltTab para
/// llegar a ventanas que kAXWindowsAttribute no devuelve.
@_silgen_name("_AXUIElementCreateWithRemoteToken")
func _AXUIElementCreateWithRemoteToken(_ token: CFData) -> Unmanaged<AXUIElement>?

/// Resultado de una llamada AX: valor (si lo hay), error y duración.
struct AXCall<Value> {
    let value: Value?
    let error: AXError
    let milliseconds: Double

    /**
     * @brief  Describe el resultado en una sola línea.
     *
     * @param[in]  render  Función que convierte el valor en texto.
     * @return Texto con valor o error y la duración de la llamada.
     */
    func describe(_ render: (Value) -> String) -> String {
        let time = String(format: "%.1f ms", milliseconds)
        if error == .success, let value {
            return "\(render(value))  [\(time)]"
        }
        return "ERROR \(AXInspector.name(error))  [\(time)]"
    }
}

@MainActor
enum AXInspector {

    /**
     * @brief  Traduce un AXError a su nombre y a una explicación breve.
     *
     * @param[in]  error  Código devuelto por la API de Accesibilidad.
     * @return Nombre del código, su valor numérico y qué significa.
     */
    nonisolated static func name(_ error: AXError) -> String {
        let text: String
        switch error {
        case .success: text = "success"
        case .failure: text = "failure (fallo genérico del sistema)"
        case .illegalArgument: text = "illegalArgument (argumento no válido)"
        case .invalidUIElement: text = "invalidUIElement (la ventana ya no existe)"
        case .invalidUIElementObserver: text = "invalidUIElementObserver"
        case .cannotComplete: text = "cannotComplete (la app no responde o la mensajería AX falla)"
        case .attributeUnsupported: text = "attributeUnsupported (atributo no soportado)"
        case .actionUnsupported: text = "actionUnsupported"
        case .notificationUnsupported: text = "notificationUnsupported"
        case .notImplemented: text = "notImplemented (la app no implementa Accesibilidad)"
        case .notificationAlreadyRegistered: text = "notificationAlreadyRegistered"
        case .notificationNotRegistered: text = "notificationNotRegistered"
        case .apiDisabled: text = "apiDisabled (sin permiso de Accesibilidad)"
        case .noValue: text = "noValue (el atributo no tiene valor)"
        case .parameterizedAttributeUnsupported: text = "parameterizedAttributeUnsupported"
        case .notEnoughPrecision: text = "notEnoughPrecision"
        @unknown default: text = "desconocido"
        }
        return "\(error.rawValue) \(text)"
    }

    /**
     * @brief  Ejecuta una operación midiendo su duración en milisegundos.
     *
     * @param[in]  body  Operación a medir.
     * @return Par con el resultado de la operación y su duración.
     */
    static func timed<T>(_ body: () -> T) -> (T, Double) {
        let start = DispatchTime.now().uptimeNanoseconds
        let result = body()
        let end = DispatchTime.now().uptimeNanoseconds
        return (result, Double(end - start) / 1_000_000)
    }

    /**
     * @brief  Lee un atributo AX sin interpretar su tipo.
     *
     * @param[in]  element    Elemento AX (app o ventana).
     * @param[in]  attribute  Nombre del atributo, por ejemplo kAXPositionAttribute.
     * @return Resultado con el valor CFTypeRef, el error y la duración.
     */
    static func attribute(_ element: AXUIElement, _ attribute: String) -> AXCall<CFTypeRef> {
        var value: CFTypeRef?
        let (error, ms) = timed { AXUIElementCopyAttributeValue(element, attribute as CFString, &value) }
        return AXCall(value: value, error: error, milliseconds: ms)
    }

    /**
     * @brief  Lee un atributo de texto (título, rol, subrol…).
     *
     * @param[in]  element    Elemento AX.
     * @param[in]  attribute  Nombre del atributo.
     * @return Resultado con el texto, el error y la duración.
     */
    static func string(_ element: AXUIElement, _ attribute: String) -> AXCall<String> {
        let call = self.attribute(element, attribute)
        return AXCall(value: call.value as? String, error: call.error, milliseconds: call.milliseconds)
    }

    /**
     * @brief  Lee la lista de ventanas de una app.
     *
     * @param[in]  app  Elemento AX de la aplicación.
     * @return Resultado con las ventanas, el error y la duración.
     */
    static func windows(_ app: AXUIElement) -> AXCall<[AXUIElement]> {
        let call = attribute(app, kAXWindowsAttribute)
        return AXCall(value: call.value as? [AXUIElement], error: call.error, milliseconds: call.milliseconds)
    }

    /**
     * @brief  Lee la ventana con el foco de una app.
     *
     * @param[in]  app  Elemento AX de la aplicación.
     * @return Resultado con la ventana, el error y la duración.
     */
    static func focusedWindow(_ app: AXUIElement) -> AXCall<AXUIElement> {
        let call = attribute(app, kAXFocusedWindowAttribute)
        guard let value = call.value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return AXCall(value: nil, error: call.error, milliseconds: call.milliseconds)
        }
        return AXCall(value: (value as! AXUIElement), error: call.error, milliseconds: call.milliseconds)
    }

    /**
     * @brief  Lee la posición de una ventana (origen arriba a la izquierda).
     *
     * @param[in]  window  Elemento AX de la ventana.
     * @return Resultado con el punto, el error y la duración.
     */
    static func position(_ window: AXUIElement) -> AXCall<CGPoint> {
        let call = attribute(window, kAXPositionAttribute)
        var point = CGPoint.zero
        guard let value = call.value, CFGetTypeID(value) == AXValueGetTypeID(),
              AXValueGetValue(value as! AXValue, .cgPoint, &point) else {
            return AXCall(value: nil, error: call.error, milliseconds: call.milliseconds)
        }
        return AXCall(value: point, error: call.error, milliseconds: call.milliseconds)
    }

    /**
     * @brief  Lee el tamaño de una ventana.
     *
     * @param[in]  window  Elemento AX de la ventana.
     * @return Resultado con el tamaño, el error y la duración.
     */
    static func size(_ window: AXUIElement) -> AXCall<CGSize> {
        let call = attribute(window, kAXSizeAttribute)
        var size = CGSize.zero
        guard let value = call.value, CFGetTypeID(value) == AXValueGetTypeID(),
              AXValueGetValue(value as! AXValue, .cgSize, &size) else {
            return AXCall(value: nil, error: call.error, milliseconds: call.milliseconds)
        }
        return AXCall(value: size, error: call.error, milliseconds: call.milliseconds)
    }

    /**
     * @brief  Indica si un atributo se puede modificar.
     *
     * @param[in]  element    Elemento AX.
     * @param[in]  attribute  Nombre del atributo.
     * @return Resultado con el booleano, el error y la duración.
     */
    static func settable(_ element: AXUIElement, _ attribute: String) -> AXCall<Bool> {
        var flag = DarwinBoolean(false)
        let (error, ms) = timed { AXUIElementIsAttributeSettable(element, attribute as CFString, &flag) }
        return AXCall(value: flag.boolValue, error: error, milliseconds: ms)
    }

    /**
     * @brief  Mueve una ventana a un punto (origen arriba a la izquierda).
     *
     * @param[in]  window  Elemento AX de la ventana.
     * @param[in]  point   Nueva posición.
     * @return Resultado sin valor, con el error y la duración.
     */
    static func setPosition(_ window: AXUIElement, _ point: CGPoint) -> AXCall<Void> {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else {
            return AXCall(value: nil, error: .failure, milliseconds: 0)
        }
        let (error, ms) = timed { AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value) }
        return AXCall(value: (), error: error, milliseconds: ms)
    }

    /**
     * @brief  Cambia el tamaño de una ventana.
     *
     * @param[in]  window  Elemento AX de la ventana.
     * @param[in]  size    Nuevo tamaño.
     * @return Resultado sin valor, con el error y la duración.
     */
    static func setSize(_ window: AXUIElement, _ size: CGSize) -> AXCall<Void> {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else {
            return AXCall(value: nil, error: .failure, milliseconds: 0)
        }
        let (error, ms) = timed { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value) }
        return AXCall(value: (), error: error, milliseconds: ms)
    }

    /**
     * @brief  Obtiene el CGWindowID de una ventana AX.
     *
     * @param[in]  window  Elemento AX de la ventana.
     * @return Resultado con el identificador, el error y la duración.
     */
    static func windowID(_ window: AXUIElement) -> AXCall<CGWindowID> {
        var id: CGWindowID = 0
        let (error, ms) = timed { _AXUIElementGetWindow(window, &id) }
        return AXCall(value: error == .success ? id : nil, error: error, milliseconds: ms)
    }

    /**
     * @brief  Lee de WindowServer el marco de una ventana, sin pasar por AX.
     *
     * @param[in]  id  CGWindowID de la ventana.
     * @return Marco en coordenadas globales (origen arriba a la izquierda), o nil.
     */
    static func windowServerBounds(_ id: CGWindowID) -> CGRect? {
        guard let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]],
              let info = list.first,
              let bounds = info[kCGWindowBounds as String] as? NSDictionary else {
            return nil
        }
        return CGRect(dictionaryRepresentation: bounds as CFDictionary)
    }

    /**
     * @brief  Devuelve las ventanas normales que WindowServer ve para un proceso.
     *
     * @param[in]  pid  Identificador del proceso.
     * @return Lista de pares (CGWindowID, marco global con origen arriba a la izquierda).
     */
    static func windowServerWindows(_ pid: pid_t) -> [(id: CGWindowID, bounds: CGRect)] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { info in
            guard (info[kCGWindowOwnerPID as String] as? Int) == Int(pid),
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let id = info[kCGWindowNumber as String] as? Int,
                  let dict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dict as CFDictionary) else {
                return nil
            }
            return (CGWindowID(id), bounds)
        }
    }

    /**
     * @brief  Busca ventanas recorriendo identificadores internos de AX (tokens remotos).
     *
     * Vía alternativa a kAXWindowsAttribute: crea elementos AX con
     * _AXUIElementCreateWithRemoteToken para los identificadores 0..<limit y
     * se queda con los que dicen ser ventanas (rol AXWindow).
     *
     * @param[in]  pid    Identificador del proceso.
     * @param[in]  limit  Número de identificadores a probar.
     * @return Elementos AX con rol AXWindow.
     */
    static func remoteTokenWindows(_ pid: pid_t, limit: UInt64 = 2000) -> [AXUIElement] {
        var token = Data(count: 20)
        token.replaceSubrange(0..<4, with: withUnsafeBytes(of: Int32(pid)) { Data($0) })
        token.replaceSubrange(4..<8, with: withUnsafeBytes(of: Int32(0)) { Data($0) })
        token.replaceSubrange(8..<12, with: withUnsafeBytes(of: Int32(0x636f636f)) { Data($0) })
        var found: [AXUIElement] = []
        for elementID in 0..<limit {
            token.replaceSubrange(12..<20, with: withUnsafeBytes(of: elementID) { Data($0) })
            guard let element = _AXUIElementCreateWithRemoteToken(token as CFData)?.takeRetainedValue() else {
                continue
            }
            AXUIElementSetMessagingTimeout(element, 0.2)
            if string(element, kAXRoleAttribute).value == kAXWindowRole {
                found.append(element)
            }
        }
        return found
    }

    /**
     * @brief  Pide a AX el elemento que hay en un punto de la pantalla y sube hasta su ventana.
     *
     * Vía alternativa a kAXWindowsAttribute basada en hit-testing.
     *
     * @param[in]  point  Punto global (origen arriba a la izquierda).
     * @return Resultado con la ventana encontrada, el error y la duración.
     */
    static func windowAt(_ point: CGPoint) -> AXCall<AXUIElement> {
        var element: AXUIElement?
        let systemWide = AXUIElementCreateSystemWide()
        let (error, ms) = timed {
            AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element)
        }
        guard error == .success, let element else {
            return AXCall(value: nil, error: error, milliseconds: ms)
        }
        if string(element, kAXRoleAttribute).value == kAXWindowRole {
            return AXCall(value: element, error: .success, milliseconds: ms)
        }
        let window = attribute(element, kAXWindowAttribute)
        guard let value = window.value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return AXCall(value: nil, error: window.error == .success ? .noValue : window.error,
                          milliseconds: ms + window.milliseconds)
        }
        return AXCall(value: (value as! AXUIElement), error: .success, milliseconds: ms + window.milliseconds)
    }

    /**
     * @brief  Cuenta las ventanas normales que WindowServer ve para un proceso.
     *
     * Sirve para contrastar: si WindowServer ve ventanas y AX devuelve cero,
     * el fallo está en Accesibilidad, no en la app.
     *
     * @param[in]  pid  Identificador del proceso.
     * @return Número de ventanas en pantalla de la capa 0.
     */
    static func windowServerCount(_ pid: pid_t) -> Int {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]] else {
            return 0
        }
        return list.filter {
            ($0[kCGWindowOwnerPID as String] as? Int) == Int(pid)
                && ($0[kCGWindowLayer as String] as? Int) == 0
        }.count
    }
}
