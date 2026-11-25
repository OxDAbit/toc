/*
-------------------------------------------------------------------------------
Name:     Sources/toc/AppleEventsMover.swift
Purpose:  Plan B sin Accesibilidad: mueve la ventana delantera de las apps
          scriptables (Finder, Safari, Ajustes…) mediante Apple Events. Es la
          única vía que sigue funcionando con el fallo de AX tras el reposo.
          Cada orden tiene un tiempo máximo, para no dejar a toc congelada si
          la app tarda en responder.
Version:  v0.0.3
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit

@MainActor
enum AppleEventsMover {

    /**
     * @brief  Indica si una app declara soporte de AppleScript.
     *
     * @param[in]  app  App en ejecución.
     * @return true si su Info.plist tiene NSAppleScriptEnabled u OSAScriptingDefinition.
     */
    static func isScriptable(_ app: NSRunningApplication) -> Bool {
        guard let url = app.bundleURL, let bundle = Bundle(url: url) else { return false }
        let enabled = bundle.object(forInfoDictionaryKey: "NSAppleScriptEnabled")
        if let flag = enabled as? Bool, flag { return true }
        if let text = enabled as? String, ["yes", "true"].contains(text.lowercased()) { return true }
        return bundle.object(forInfoDictionaryKey: "OSAScriptingDefinition") != nil
    }

    /// Tiempo máximo, en segundos, que se espera la respuesta de la app.
    static let replyTimeout = 2

    /**
     * @brief  Ejecuta un AppleScript con un tiempo máximo de espera.
     *
     * @param[in]  source  Código AppleScript (una orden).
     * @return Par con el resultado (o nil) y el mensaje de error (o nil).
     */
    static func run(_ source: String) -> (NSAppleEventDescriptor?, String?) {
        let wrapped = "with timeout of \(replyTimeout) seconds\n\(source)\nend timeout"
        guard let script = NSAppleScript(source: wrapped) else { return (nil, "script no válido") }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let number = errorInfo[NSAppleScript.errorNumber] ?? "?"
            let message = errorInfo[NSAppleScript.errorMessage] ?? "?"
            return (nil, "\(number) \(message)")
        }
        return (result, nil)
    }

    /**
     * @brief  Lee el marco de la ventana delantera de una app scriptable.
     *
     * @param[in]  bundleID  Identificador de la app.
     * @return Marco con origen arriba a la izquierda, o nil si no se puede leer.
     */
    static func frame(bundleID: String) -> CGRect? {
        let (result, error) = run("tell application id \"\(bundleID)\" to get bounds of front window")
        guard let result, result.numberOfItems == 4 else {
            Log.mover.error("Apple Events no lee los límites de \(bundleID, privacy: .public): \(error ?? "?", privacy: .public)")
            return nil
        }
        let v = (1...4).map { CGFloat(result.atIndex($0)?.int32Value ?? 0) }
        return CGRect(x: v[0], y: v[1], width: v[2] - v[0], height: v[3] - v[1])
    }

    /**
     * @brief  Coloca la ventana delantera de una app scriptable y devuelve dónde ha quedado.
     *
     * @param[in]  bundleID  Identificador de la app.
     * @param[in]  target    Marco de destino con origen arriba a la izquierda.
     * @return Marco leído después del cambio, o nil si falla.
     */
    static func setFrame(bundleID: String, to target: CGRect) -> CGRect? {
        let bounds = [target.minX, target.minY, target.maxX, target.maxY]
            .map { String(Int($0.rounded())) }
            .joined(separator: ", ")
        let (_, error) = run("tell application id \"\(bundleID)\" to set bounds of front window to {\(bounds)}")
        if let error {
            Log.mover.error("Apple Events no mueve \(bundleID, privacy: .public): \(error, privacy: .public)")
            return nil
        }
        return frame(bundleID: bundleID)
    }
}
