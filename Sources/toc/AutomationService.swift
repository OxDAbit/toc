/*
-------------------------------------------------------------------------------
Name:     Sources/toc/AutomationService.swift
Purpose:  Permiso de Automatización (Apple Events) por app. Lo comprueba sin
          bloquear y lo pide en segundo plano, para que la ventana de permiso
          de macOS nunca deje a toc congelada esperando la respuesta. También
          lista qué apps abiertas están listas para el plan B.
Version:  v0.0.3
Author:   David Alvarez Medina aka 0xDA_bit
Created:  25/11/2026
-------------------------------------------------------------------------------
*/

import AppKit
import CoreServices

/// Estado del permiso de Automatización de toc sobre una app.
enum AutomationStatus: Sendable, Equatable {
    case granted
    case denied
    case notDetermined
    case notRunning
    case unknown(OSStatus)

    /// Descripción breve para el diagnóstico.
    var label: String {
        switch self {
        case .granted: "concedido"
        case .denied: "denegado"
        case .notDetermined: "sin pedir"
        case .notRunning: "app cerrada"
        case .unknown(let status): "desconocido (\(status))"
        }
    }
}

/// App scriptable abierta y su permiso de Automatización.
struct ScriptableApp {
    let name: String
    let bundleID: String
    let status: AutomationStatus
}

@MainActor
enum AutomationService {

    /**
     * @brief  Consulta (y opcionalmente pide) el permiso de Automatización sobre una app.
     *
     * Con ask = false responde al momento. Con ask = true macOS puede mostrar
     * su ventana de permiso y la llamada espera la respuesta: no se debe usar
     * desde el hilo principal.
     *
     * @param[in]  bundleID  Identificador de la app de destino.
     * @param[in]  ask       Si se pide el permiso cuando aún no se ha decidido.
     * @return Estado del permiso.
     */
    nonisolated static func status(bundleID: String, ask: Bool) -> AutomationStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        guard let address = target.aeDesc else { return .unknown(OSStatus(paramErr)) }
        let status = AEDeterminePermissionToAutomateTarget(address, typeWildCard, typeWildCard, ask)
        switch status {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted): return .denied
        case OSStatus(errAEEventWouldRequireUserConsent): return .notDetermined
        case OSStatus(procNotFound): return .notRunning
        default: return .unknown(status)
        }
    }

    /**
     * @brief  Pide el permiso sobre varias apps en segundo plano, una detrás de otra.
     *
     * @param[in]  bundleIDs   Apps de destino.
     * @param[in]  completion  Se llama en el hilo principal con el resultado de cada app.
     */
    static func request(_ bundleIDs: [String],
                        completion: @escaping @MainActor @Sendable ([String: AutomationStatus]) -> Void) {
        guard !bundleIDs.isEmpty else {
            completion([:])
            return
        }
        Task.detached(priority: .userInitiated) {
            var results: [String: AutomationStatus] = [:]
            for id in bundleIDs {
                let result = status(bundleID: id, ask: true)
                results[id] = result
                Log.mover.notice("Permiso de Automatización para \(id, privacy: .public): \(result.label, privacy: .public)")
            }
            let finished = results
            await MainActor.run { completion(finished) }
        }
    }

    /**
     * @brief  Lista las apps abiertas que toc puede mover por Apple Events.
     *
     * @return Apps normales scriptables abiertas, con su permiso actual, por nombre.
     */
    static func scriptableApps() -> [ScriptableApp] {
        let own = getpid()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != own }
            .filter(AppleEventsMover.isScriptable)
            .compactMap { app in
                guard let id = app.bundleIdentifier else { return nil }
                return ScriptableApp(name: app.localizedName ?? id, bundleID: id,
                                     status: status(bundleID: id, ask: false))
            }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}
