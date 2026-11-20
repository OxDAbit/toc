/*
-------------------------------------------------------------------------------
Name:     Sources/toc/LifecycleMonitor.swift
Purpose:  Avisa a toc cuando el Mac despierta, se encienden las pantallas,
          vuelve la sesión o cambia la configuración de pantallas, para que
          reconstruya los atajos y compruebe Accesibilidad.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit

@MainActor
final class LifecycleMonitor {

    private var tokens: [NSObjectProtocol] = []

    /**
     * @brief  Empieza a escuchar los eventos del sistema.
     *
     * @param[in]  handler  Función que recibe el nombre del evento.
     */
    func start(_ handler: @escaping @MainActor @Sendable (String) -> Void) {
        let workspace = NSWorkspace.shared.notificationCenter
        let events: [(Notification.Name, String)] = [
            (NSWorkspace.didWakeNotification, "despertar"),
            (NSWorkspace.screensDidWakeNotification, "pantallas encendidas"),
            (NSWorkspace.sessionDidBecomeActiveNotification, "sesión activa")
        ]
        for (name, label) in events {
            tokens.append(workspace.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { handler(label) }
            })
        }
        tokens.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { handler("cambio de pantallas") }
            })
    }
}
