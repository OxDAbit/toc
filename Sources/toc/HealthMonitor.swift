/*
-------------------------------------------------------------------------------
Name:     Sources/toc/HealthMonitor.swift
Purpose:  Comprueba el estado de Accesibilidad observando las apps con
          ventanas en pantalla, avisa cuando cambia y genera el informe de
          diagnóstico que se puede copiar desde el menú.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit
import TocCore

@MainActor
final class HealthMonitor {

    /// Estado actual de Accesibilidad.
    private(set) var state: AXHealth = .unknown
    /// Se llama cada vez que el estado cambia.
    var onChange: ((AXHealth) -> Void)?
    /// Informe de la última comprobación.
    private(set) var diagnostics = "Todavía no se ha hecho ninguna comprobación."

    /// Número máximo de apps que se observan en cada comprobación.
    private let sampleSize = 4

    /**
     * @brief  Comprueba el estado de Accesibilidad con las apps que tienen ventanas.
     */
    func check() {
        guard AXIsProcessTrusted() else {
            diagnostics = report(state: .permissionMissing, lines: ["Sin permiso de Accesibilidad."])
            update(.permissionMissing)
            return
        }
        let own = getpid()
        var counts: [pid_t: Int] = [:]
        var order: [pid_t] = []
        for window in WindowServerService.onScreenWindows() where window.pid != own {
            if counts[window.pid] == nil { order.append(window.pid) }
            counts[window.pid, default: 0] += 1
        }
        let pids = order.filter {
            NSRunningApplication(processIdentifier: $0)?.activationPolicy == .regular
        }.prefix(sampleSize)

        var lines: [String] = []
        let observations = pids.map { pid -> AXObservation in
            let observation = AXWindowService.observe(pid: pid, windowServerWindows: counts[pid] ?? 0)
            let name = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "pid \(pid)"
            lines.append("\(name): WindowServer=\(observation.windowServerWindows) AXError=\(observation.error) "
                         + "roles=\(observation.roles) → \(AXHealthDetector.evaluate(observation))")
            return observation
        }
        let result = AXHealthDetector.evaluate(Array(observations))
        diagnostics = report(state: result, lines: lines)
        Log.ax.info("Comprobación de Accesibilidad: \(String(describing: result))")
        update(result)
    }

    /**
     * @brief  Registra un estado detectado fuera de una comprobación (por ejemplo, al mover).
     *
     * @param[in]  health  Estado detectado.
     */
    func report(_ health: AXHealth) {
        update(health)
    }

    /**
     * @brief  Cambia el estado y avisa si es distinto del anterior.
     *
     * @param[in]  health  Nuevo estado.
     */
    private func update(_ health: AXHealth) {
        guard health != state else { return }
        state = health
        onChange?(health)
    }

    /**
     * @brief  Compone el informe de diagnóstico.
     *
     * @param[in]  state  Estado resultante.
     * @param[in]  lines  Detalle por app.
     * @return Texto del informe.
     */
    private func report(state: AXHealth, lines: [String]) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        return ([
            "toc \(version) · diagnóstico de Accesibilidad",
            "Fecha: \(formatter.string(from: Date()))",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Estado: \(state)",
            ""
        ] + lines).joined(separator: "\n")
    }
}
