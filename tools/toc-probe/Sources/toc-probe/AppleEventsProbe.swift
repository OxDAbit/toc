/*
-------------------------------------------------------------------------------
Name:     tools/toc-probe/Sources/toc-probe/AppleEventsProbe.swift
Purpose:  Vía alternativa sin Accesibilidad: lee y cambia el marco de la
          ventana delantera de apps scriptables (Finder, Safari…) mediante
          Apple Events. Requiere el permiso de Automatización.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit

@MainActor
enum AppleEventsProbe {

    /**
     * @brief  Ejecuta un AppleScript y devuelve su resultado o su error.
     *
     * @param[in]  source  Código AppleScript.
     * @return Par con el descriptor resultante (o nil) y el mensaje de error (o nil).
     */
    static func run(_ source: String) -> (NSAppleEventDescriptor?, String?) {
        guard let script = NSAppleScript(source: source) else {
            return (nil, "no se pudo compilar el script")
        }
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
     * @param[in]  bundleID  Identificador de la app, por ejemplo com.apple.finder.
     * @return Par con los límites {izquierda, arriba, derecha, abajo} (o nil) y el error (o nil).
     */
    static func bounds(_ bundleID: String) -> ([Int]?, String?) {
        let (result, error) = run("tell application id \"\(bundleID)\" to get bounds of front window")
        guard let result, result.numberOfItems == 4 else {
            return (nil, error ?? "respuesta inesperada")
        }
        let values = (1...4).map { Int(result.atIndex($0)?.int32Value ?? 0) }
        return (values, nil)
    }

    /**
     * @brief  Cambia el marco de la ventana delantera de una app scriptable.
     *
     * @param[in]  bundleID  Identificador de la app.
     * @param[in]  values    Límites {izquierda, arriba, derecha, abajo}.
     * @return Mensaje de error, o nil si la orden se aceptó.
     */
    static func setBounds(_ bundleID: String, _ values: [Int]) -> String? {
        let list = values.map(String.init).joined(separator: ", ")
        return run("tell application id \"\(bundleID)\" to set bounds of front window to {\(list)}").1
    }

    /**
     * @brief  Mueve 40 px la ventana delantera con Apple Events y la devuelve a su sitio.
     *
     * @param[in]  bundleID  Identificador de la app.
     * @return true si la ventana se movió de verdad.
     */
    static func moveTest(_ bundleID: String) -> Bool {
        let (before, readError) = bounds(bundleID)
        guard let before else {
            print("    Apple Events: no se pueden leer los límites: \(readError ?? "?")")
            return false
        }
        print("    Apple Events: límites \(before)")
        let target = [before[0] + 40, before[1], before[2] + 40, before[3]]
        if let error = setBounds(bundleID, target) {
            print("    Apple Events: mover falla: \(error)")
            return false
        }
        settle(0.3)
        let (after, _) = bounds(bundleID)
        print("    Apple Events: tras mover \(after.map { "\($0)" } ?? "ilegible")")
        _ = setBounds(bundleID, before)
        let moved = after == target
        print("    Apple Events: \(moved ? "MUEVE LA VENTANA" : "no la mueve")")
        return moved
    }
}
