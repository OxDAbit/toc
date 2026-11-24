/*
-------------------------------------------------------------------------------
Name:     Sources/toc/AppDelegate.swift
Purpose:  Arranque y coordinación de toc: permiso de Accesibilidad, menú,
          preferencias, atajos, comprobaciones de salud al despertar y avisos
          al usuario cuando macOS pierde el acceso a las ventanas.
Version:  v0.0.2
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
    private lazy var snap = SnapController { [weak self] action in self?.run(action) }
    private let store = PreferencesStore()
    private lazy var preferencesWindow = PreferencesWindowController(store: store)
    private var menu: StatusMenuController?
    /// Observador del cambio de distribución de teclado.
    private var keyboardObserver: NSObjectProtocol?
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
            onToggleSnap: { [weak self] in self?.toggleSnap() },
            onToggleLogin: { [weak self] in self?.toggleLogin() },
            onCheck: { [weak self] in self?.health.check() },
            onCopyDiagnostics: { [weak self] in self?.copyDiagnostics() },
            onPreferences: { [weak self] in self?.preferencesWindow.show() }
        )
        health.onChange = { [weak self] state in self?.healthChanged(state) }

        store.onShortcutsChange = { [weak self] in self?.shortcutsChanged() }
        store.onSnapChange = { [weak self] enabled in
            self?.snap.isEnabled = enabled
            self?.refreshOptions()
        }
        store.onRecordingChange = { [weak self] recording in self?.recordingChanged(recording) }

        snap.isEnabled = store.snapEnabled
        shortcutsChanged()
        refreshOptions()

        lifecycle.start { [weak self] event in self?.systemEvent(event) }
        keyboardObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.keyboardLayoutChanged() }
            }
        health.check()
    }

    /**
     * @brief  Registra los atajos vigentes y rehace las acciones del menú.
     */
    private func shortcutsChanged() {
        menu?.rebuildActions(store.preferences)
        hotkeys.register(store.preferences.activeShortcuts().map { action, shortcut in
            HotkeyBinding(id: action.rawValue, shortcut: shortcut, name: action.title) { [weak self] in
                self?.run(action)
            }
        })
        hotkeysUpdated()
    }

    /**
     * @brief  Vuelve a mostrar los atajos con los nombres de la nueva distribución de teclado.
     *
     * Los atajos se registran por la posición física de la tecla, así que no
     * hace falta volver a registrarlos: solo cambia cómo se muestran.
     */
    private func keyboardLayoutChanged() {
        Log.lifecycle.info("Cambio de distribución de teclado")
        store.keyboardLayoutChanged()
        menu?.rebuildActions(store.preferences)
        hotkeysUpdated()
    }

    /**
     * @brief  Suspende los atajos globales mientras se graba uno nuevo, y los recupera al terminar.
     *
     * @param[in]  recording  true al empezar a grabar.
     */
    private func recordingChanged(_ recording: Bool) {
        if recording {
            hotkeys.unregisterAll()
        } else {
            hotkeys.reregister()
            hotkeysUpdated()
        }
    }

    /**
     * @brief  Comunica al menú y a las preferencias qué atajos no se pudieron registrar.
     */
    private func hotkeysUpdated() {
        store.failedActions = hotkeys.failedIDs
        menu?.update(failedHotkeys: hotkeys.failed)
    }

    /**
     * @brief  Activa o desactiva el ajuste al arrastrar.
     */
    private func toggleSnap() {
        store.setSnapEnabled(!store.snapEnabled)
    }

    /**
     * @brief  Activa o desactiva la apertura al iniciar sesión.
     */
    private func toggleLogin() {
        if let error = store.setLoginEnabled(!store.loginEnabled) {
            let alert = NSAlert()
            alert.messageText = "No se pudo cambiar la apertura al iniciar sesión"
            alert.informativeText = error
            NSApp.activate()
            alert.runModal()
        }
        refreshOptions()
    }

    /**
     * @brief  Refleja en el menú el estado de las opciones.
     */
    private func refreshOptions() {
        store.refreshLogin()
        menu?.update(snapEnabled: store.snapEnabled, loginEnabled: store.loginEnabled,
                     loginPending: store.loginPending)
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
        if store.recordingAction == nil {
            hotkeys.reregister()
            hotkeysUpdated()
        }
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
