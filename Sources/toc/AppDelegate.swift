/*
-------------------------------------------------------------------------------
Name:     Sources/toc/AppDelegate.swift
Purpose:  Arranque y coordinación de toc: permiso de Accesibilidad, menú,
          atajos, comprobaciones de salud al despertar y avisos al usuario
          cuando macOS pierde el acceso a las ventanas.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit
import TocCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let mover = WindowMover()
    private let health = HealthMonitor()
    private let hotkeys = HotkeyService()
    private let lifecycle = LifecycleMonitor()
    private var menu: StatusMenuController?
    /// Evita repetir el aviso del fallo mientras dura el mismo episodio.
    private var brokenAlertShown = false

    /// Segundos que se espera tras despertar antes de comprobar Accesibilidad.
    private let wakeCheckDelay: Duration = .seconds(3)

    /**
     * @brief  Prepara toc al arrancar.
     *
     * @param[in]  notification  Notificación de arranque (no se usa).
     */
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)

        menu = StatusMenuController(
            onAction: { [weak self] action in self?.run(action) },
            onCheck: { [weak self] in self?.health.check() },
            onCopyDiagnostics: { [weak self] in self?.copyDiagnostics() }
        )
        health.onChange = { [weak self] state in self?.healthChanged(state) }

        hotkeys.register(WindowAction.allCases.compactMap { action in
            action.defaultShortcut.map { shortcut in
                HotkeyBinding(shortcut: shortcut, name: action.title) { [weak self] in self?.run(action) }
            }
        })
        menu?.update(failedHotkeys: hotkeys.failed)

        lifecycle.start { [weak self] event in self?.systemEvent(event) }
        health.check()
    }

    /**
     * @brief  Ejecuta una acción y reacciona a su resultado.
     *
     * @param[in]  action  Acción a ejecutar.
     */
    private func run(_ action: WindowAction) {
        switch mover.perform(action) {
        case .moved:
            break
        case .notMoved(let reason):
            Log.mover.info("No se movió: \(reason)")
            NSSound.beep()
        case .unavailable(let state, let reason):
            Log.mover.error("Acción no disponible: \(reason)")
            health.report(state)
            NSSound.beep()
            alert(for: state, reason: reason)
        }
    }

    /**
     * @brief  Reacciona a un evento del sistema (despertar, pantallas…).
     *
     * @param[in]  event  Nombre del evento.
     */
    private func systemEvent(_ event: String) {
        Log.lifecycle.info("Evento del sistema: \(event)")
        hotkeys.reregister()
        menu?.update(failedHotkeys: hotkeys.failed)
        Task { [weak self, wakeCheckDelay] in
            try? await Task.sleep(for: wakeCheckDelay)
            self?.health.check()
        }
    }

    /**
     * @brief  Actualiza el menú cuando cambia el estado de Accesibilidad.
     *
     * @param[in]  state  Nuevo estado.
     */
    private func healthChanged(_ state: AXHealth) {
        menu?.update(health: state)
        if state == .healthy { brokenAlertShown = false }
    }

    /**
     * @brief  Avisa al usuario de que una acción no se puede hacer y por qué.
     *
     * @param[in]  state   Estado de Accesibilidad.
     * @param[in]  reason  Motivo concreto.
     */
    private func alert(for state: AXHealth, reason: String) {
        let alert = NSAlert()
        switch state {
        case .broken:
            guard !brokenAlertShown else { return }
            brokenAlertShown = true
            alert.messageText = "macOS ha dejado de dar acceso a las ventanas"
            alert.informativeText = """
            Es un fallo de macOS tras el reposo: afecta a todas las apps que gestionan ventanas.
            toc seguirá moviendo las apps scriptables (Finder, Safari, Ajustes…). Para el resto, \
            reinicia el Mac; cerrar sesión no basta.

            Detalle: \(reason).
            """
            alert.addButton(withTitle: "Entendido")
            alert.addButton(withTitle: "Copiar diagnóstico")
        case .permissionMissing:
            alert.messageText = "toc necesita el permiso de Accesibilidad"
            alert.informativeText = "Actívalo en Ajustes del Sistema → Privacidad y seguridad → Accesibilidad."
            alert.addButton(withTitle: "Abrir Ajustes")
            alert.addButton(withTitle: "Cancelar")
        default:
            return
        }
        NSApp.activate()
        let response = alert.runModal()
        if state == .broken, response == .alertSecondButtonReturn {
            copyDiagnostics()
        }
        if state == .permissionMissing, response == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /**
     * @brief  Hace una comprobación nueva y copia su informe al portapapeles.
     */
    private func copyDiagnostics() {
        health.check()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(health.diagnostics, forType: .string)
    }
}
