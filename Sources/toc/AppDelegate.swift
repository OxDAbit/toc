/*
-------------------------------------------------------------------------------
Name:     Sources/toc/AppDelegate.swift
Purpose:  Arranque y coordinación de toc: permiso de Accesibilidad, menú,
          preferencias, atajos, comprobaciones de salud al despertar, permisos
          del plan B y avisos al usuario cuando macOS pierde el acceso a las
          ventanas. Recuerda la última app activa para que los avisos de toc
          no le quiten el destino a los atajos.
Version:  v0.0.3
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
    /// Última app activa que no es toc: destino de los atajos y del menú.
    private var lastExternalApp: NSRunningApplication?
    /// Observador de los cambios de app activa.
    private var activationObserver: NSObjectProtocol?

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
            onPrepareFallback: { [weak self] in self?.prepareFallback() },
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

        lastExternalApp = Self.externalFrontmost()
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                MainActor.assumeIsolated {
                    if let app, app.processIdentifier != getpid() { self?.lastExternalApp = app }
                }
            }

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
        Log.lifecycle.notice("Cambio de distribución de teclado")
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
            present(alert)
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
        switch mover.perform(action, on: targetApp()) {
        case .moved:
            break
        case .notMoved(let reason):
            Log.mover.notice("No se movió: \(reason, privacy: .public)")
            NSSound.beep()
        case .unavailable(let state, let reason):
            Log.mover.error("Acción no disponible: \(reason, privacy: .public)")
            health.report(state)
            NSSound.beep()
            alert(for: state, reason: reason)
        case .needsAutomation(let app, let denied):
            Log.mover.error("Falta el permiso de Automatización para \(app, privacy: .public) (denegado: \(denied))")
            NSSound.beep()
            // Si aún no se ha decidido, macOS ya está mostrando su ventana de permiso.
            if denied { automationDeniedAlert(app: app) }
        }
    }

    /**
     * @brief  Devuelve la app sobre la que actúan los atajos y el menú.
     *
     * Es la app activa, salvo que la activa sea toc (por ejemplo, tras uno de
     * sus avisos): entonces, la última app activa antes de toc.
     *
     * @return App de destino, o nil si no hay ninguna.
     */
    private func targetApp() -> NSRunningApplication? {
        if let app = Self.externalFrontmost() { return app }
        guard let last = lastExternalApp, !last.isTerminated else { return nil }
        return last
    }

    /**
     * @brief  Devuelve la app activa si no es toc.
     *
     * @return App activa, o nil si es toc o no hay ninguna.
     */
    private static func externalFrontmost() -> NSRunningApplication? {
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid() else {
            return nil
        }
        return app
    }

    /**
     * @brief  Muestra un aviso de toc y, al cerrarlo, devuelve el foco a la app de antes.
     *
     * @param[in]  alert  Aviso a mostrar.
     * @return Botón pulsado.
     */
    @discardableResult
    private func present(_ alert: NSAlert) -> NSApplication.ModalResponse {
        let previous = targetApp()
        NSApp.activate()
        let response = alert.runModal()
        previous?.activate()
        return response
    }

    /**
     * @brief  Pide por adelantado el permiso de Automatización de las apps scriptables abiertas.
     *
     * Así, si macOS pierde el acceso a las ventanas, el plan B funciona sin
     * esperar a la ventana de permiso. Las peticiones van en segundo plano.
     */
    private func prepareFallback() {
        let apps = AutomationService.scriptableApps()
        let pending = apps.filter { $0.status == .notDetermined }
        guard !pending.isEmpty else {
            fallbackSummary(apps)
            return
        }
        Log.mover.notice("Preparando el plan B para \(pending.map(\.name).joined(separator: ", "), privacy: .public)")
        AutomationService.request(pending.map(\.bundleID)) { [weak self] _ in
            self?.fallbackSummary(AutomationService.scriptableApps())
            self?.refreshMovable()
        }
    }

    /**
     * @brief  Resume qué apps están listas para el plan B.
     *
     * @param[in]  apps  Apps scriptables abiertas con su permiso.
     */
    private func fallbackSummary(_ apps: [ScriptableApp]) {
        let ready = apps.filter { $0.status == .granted }.map(\.name)
        let denied = apps.filter { $0.status == .denied }.map(\.name)
        let alert = NSAlert()
        alert.messageText = ready.isEmpty ? "Ninguna app está lista para el plan B" : "Plan B preparado"
        var lines: [String] = []
        lines.append(ready.isEmpty
            ? "No hay apps scriptables abiertas con permiso. Abre el Finder, Safari o Ajustes y repite."
            : "Si macOS pierde el acceso a las ventanas, toc seguirá moviendo: \(ready.joined(separator: ", ")).")
        if !denied.isEmpty {
            lines.append("Sin permiso: \(denied.joined(separator: ", ")). Actívalo en Ajustes del Sistema → "
                         + "Privacidad y seguridad → Automatización → toc.")
        }
        lines.append("Solo cuentan las apps abiertas ahora: repítelo cuando abras otras.")
        alert.informativeText = lines.joined(separator: "\n\n")
        alert.addButton(withTitle: "Entendido")
        present(alert)
    }

    /**
     * @brief  Avisa de que una app no se puede mover porque se denegó la Automatización.
     *
     * @param[in]  app  Nombre de la app.
     */
    private func automationDeniedAlert(app: String) {
        let alert = NSAlert()
        alert.messageText = "toc no tiene permiso para controlar \(app)"
        alert.informativeText = "Sin Accesibilidad, toc solo puede mover \(app) con Apple Events. Actívalo en "
            + "Ajustes del Sistema → Privacidad y seguridad → Automatización → toc."
        alert.addButton(withTitle: "Abrir Ajustes")
        alert.addButton(withTitle: "Cancelar")
        if present(alert) == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    /**
     * @brief  Actualiza en el menú qué apps se pueden mover con el fallo activo.
     */
    private func refreshMovable() {
        guard health.state == .broken else { return }
        let movable = AutomationService.scriptableApps().filter { $0.status == .granted }.map(\.name)
        menu?.update(health: .broken, movable: movable)
    }

    /**
     * @brief  Reacciona a un evento del sistema (despertar, pantallas…).
     *
     * @param[in]  event  Nombre del evento.
     */
    private func systemEvent(_ event: String) {
        Log.lifecycle.notice("Evento del sistema: \(event, privacy: .public)")
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
        refreshMovable()
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
            let apps = AutomationService.scriptableApps()
            let ready = apps.filter { $0.status == .granted }.map(\.name)
            let pending = apps.filter { $0.status == .notDetermined }.map(\.name)
            var lines = ["Es un fallo de macOS tras el reposo: afecta a todas las apps que gestionan ventanas."]
            lines.append(ready.isEmpty
                ? "Ahora mismo toc no puede mover ninguna app abierta."
                : "toc sigue moviendo: \(ready.joined(separator: ", ")).")
            if !pending.isEmpty {
                lines.append("También podría mover \(pending.joined(separator: ", ")) si le das permiso: "
                             + "usa «Preparar el plan B…» en el menú de toc.")
            }
            lines.append("Para el resto, reinicia el Mac; cerrar sesión no basta.")
            lines.append("Detalle: \(reason).")
            alert.messageText = "macOS ha dejado de dar acceso a las ventanas"
            alert.informativeText = lines.joined(separator: "\n\n")
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
        let response = present(alert)
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
        let automation = AutomationService.scriptableApps()
            .map { "  \($0.name) (\($0.bundleID)): \($0.status.label)" }
        let report = health.diagnostics + "\n\nPlan B (Automatización):\n"
            + (automation.isEmpty ? "  ninguna app scriptable abierta" : automation.joined(separator: "\n"))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }
}
