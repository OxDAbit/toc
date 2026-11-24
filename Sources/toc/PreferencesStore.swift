/*
-------------------------------------------------------------------------------
Name:     Sources/toc/PreferencesStore.swift
Purpose:  Fuente única de las preferencias de toc en la app: atajos, acciones
          visibles en el menú, ajuste al arrastrar y apertura al iniciar
          sesión. Las guarda en UserDefaults y avisa de cada cambio al menú,
          a los atajos y a la ventana de preferencias.
Version:  v0.0.2
Author:   David Alvarez Medina aka 0xDA_bit
Created:  24/11/2026
-------------------------------------------------------------------------------
*/

import AppKit
import Observation
import TocCore

@MainActor
@Observable
final class PreferencesStore {

    /// Clave de UserDefaults de los atajos y la visibilidad del menú (JSON).
    private static let preferencesKey = "preferences.v1"
    /// Clave de UserDefaults del ajuste al arrastrar (la misma que en la v0.0.1).
    private static let snapKey = "snapToEdges"

    /// Atajos y visibilidad del menú.
    private(set) var preferences: TocPreferences
    /// Si el ajuste al arrastrar a los bordes está activo.
    private(set) var snapEnabled: Bool
    /// Si toc se abre al iniciar sesión.
    private(set) var loginEnabled = LoginItem.isEnabled
    /// Si macOS espera que el usuario apruebe la apertura al iniciar sesión.
    private(set) var loginPending = LoginItem.needsApproval
    /// Acciones cuyo atajo no se pudo registrar (ocupado por otra app).
    var failedActions: Set<String> = []
    /// Acción cuyo atajo se está grabando (los atajos globales se suspenden mientras tanto).
    private(set) var recordingAction: WindowAction?
    /// Indicación que se muestra mientras se graba (por ejemplo, si falta un modificador).
    private(set) var recordingHint: String?
    /// Monitor de teclado local mientras se graba un atajo.
    @ObservationIgnored private var keyMonitor: Any?
    /// Aumenta al cambiar la distribución de teclado, para que la ventana vuelva a pintar los atajos.
    private(set) var layoutRevision = 0
    /// Aviso de la última acción que perdió su atajo por un conflicto.
    private(set) var lastNotice: String?

    /// Se llama cuando cambian los atajos o las acciones visibles.
    @ObservationIgnored var onShortcutsChange: (() -> Void)?
    /// Se llama cuando cambia el ajuste al arrastrar.
    @ObservationIgnored var onSnapChange: ((Bool) -> Void)?
    /// Se llama al empezar (true) o terminar (false) la grabación de un atajo.
    @ObservationIgnored var onRecordingChange: ((Bool) -> Void)?

    /**
     * @brief  Carga las preferencias guardadas, o las de por defecto.
     */
    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Self.snapKey: true])
        snapEnabled = defaults.bool(forKey: Self.snapKey)
        if let data = defaults.data(forKey: Self.preferencesKey),
           let saved = try? JSONDecoder().decode(TocPreferences.self, from: data) {
            preferences = saved
        } else {
            preferences = TocPreferences()
        }
    }

    // MARK: - Atajos y menú

    /**
     * @brief  Devuelve el atajo vigente de una acción.
     *
     * @param[in]  action  Acción.
     * @return Atajo, o nil si no tiene.
     */
    func shortcut(for action: WindowAction) -> Shortcut? {
        preferences.shortcut(for: action)
    }

    /**
     * @brief  Asigna o quita el atajo de una acción.
     *
     * @param[in]  shortcut  Atajo nuevo, o nil para quitarlo.
     * @param[in]  action    Acción.
     */
    func setShortcut(_ shortcut: Shortcut?, for action: WindowAction) {
        let displaced = preferences.setShortcut(shortcut, for: action)
        lastNotice = displaced.isEmpty ? nil
            : "Se ha quitado el atajo de «\(displaced.map(\.title).joined(separator: "», «"))»."
        shortcutsChanged()
    }

    /**
     * @brief  Devuelve una acción a su atajo por defecto.
     *
     * @param[in]  action  Acción.
     */
    func reset(_ action: WindowAction) {
        let displaced = preferences.reset(action)
        lastNotice = displaced.isEmpty ? nil
            : "Se ha quitado el atajo de «\(displaced.map(\.title).joined(separator: "», «"))»."
        shortcutsChanged()
    }

    /**
     * @brief  Devuelve todos los atajos a sus valores por defecto.
     */
    func resetAllShortcuts() {
        preferences.resetAllShortcuts()
        lastNotice = nil
        shortcutsChanged()
    }

    /**
     * @brief  Indica si una acción aparece en el menú.
     *
     * @param[in]  action  Acción.
     * @return true si está visible.
     */
    func isVisible(_ action: WindowAction) -> Bool {
        preferences.isVisible(action)
    }

    /**
     * @brief  Muestra u oculta una acción en el menú.
     *
     * @param[in]  visible  true para mostrarla.
     * @param[in]  action   Acción.
     */
    func setVisible(_ visible: Bool, for action: WindowAction) {
        preferences.setVisible(visible, for: action)
        shortcutsChanged()
    }

    /**
     * @brief  Empieza a grabar el atajo de una acción, o termina si ya se estaba grabando.
     *
     * Mientras se graba, los atajos globales de toc se suspenden para que la
     * combinación pulsada llegue a la ventana en lugar de mover una ventana.
     * Esc cancela; ⌫ sin modificadores deja la acción sin atajo.
     *
     * @param[in]  action  Acción cuyo atajo se graba.
     */
    func toggleRecording(_ action: WindowAction) {
        if recordingAction == action {
            stopRecording()
            return
        }
        stopRecording()
        recordingAction = action
        recordingHint = nil
        lastNotice = nil
        onRecordingChange?(true)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = UInt32(event.keyCode)
            let flags = event.modifierFlags
            let handled = MainActor.assumeIsolated { self?.recordKey(keyCode, flags: flags) ?? false }
            return handled ? nil : event
        }
    }

    /**
     * @brief  Termina la grabación sin cambiar nada y reactiva los atajos globales.
     */
    func stopRecording() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        guard recordingAction != nil else { return }
        recordingAction = nil
        recordingHint = nil
        onRecordingChange?(false)
    }

    /**
     * @brief  Procesa una tecla pulsada durante la grabación.
     *
     * @param[in]  keyCode  Código virtual de la tecla.
     * @param[in]  flags    Modificadores pulsados.
     * @return true si la tecla se ha consumido.
     */
    private func recordKey(_ keyCode: UInt32, flags: NSEvent.ModifierFlags) -> Bool {
        guard let action = recordingAction else { return false }
        let modifiers = KeyEquivalent.modifiers(from: flags)
        if modifiers.isEmpty && keyCode == Shortcut.KeyCode.escape {
            stopRecording()
            return true
        }
        if modifiers.isEmpty && (keyCode == Shortcut.KeyCode.delete || keyCode == 117) {
            stopRecording()
            setShortcut(nil, for: action)
            return true
        }
        let shortcut = Shortcut(keyCode: keyCode, modifiers: modifiers)
        guard shortcut.isValidGlobal else {
            recordingHint = "Usa ⌃, ⌥ o ⌘"
            NSSound.beep()
            return true
        }
        stopRecording()
        setShortcut(shortcut, for: action)
        return true
    }

    /**
     * @brief  Guarda las preferencias y avisa del cambio.
     */
    private func shortcutsChanged() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: Self.preferencesKey)
        }
        onShortcutsChange?()
    }

    /**
     * @brief  Avisa de que ha cambiado la distribución de teclado (los nombres de las teclas cambian).
     */
    func keyboardLayoutChanged() {
        layoutRevision += 1
    }

    // MARK: - Opciones generales

    /**
     * @brief  Activa o desactiva el ajuste al arrastrar.
     *
     * @param[in]  enabled  Nuevo valor.
     */
    func setSnapEnabled(_ enabled: Bool) {
        snapEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.snapKey)
        onSnapChange?(enabled)
    }

    /**
     * @brief  Activa o desactiva la apertura al iniciar sesión.
     *
     * @param[in]  enabled  Nuevo valor.
     * @return Mensaje de error, o nil si el cambio se aplicó.
     */
    @discardableResult
    func setLoginEnabled(_ enabled: Bool) -> String? {
        let error = LoginItem.set(enabled)
        refreshLogin()
        return error
    }

    /**
     * @brief  Vuelve a leer de macOS el estado de la apertura al iniciar sesión.
     *
     * El usuario puede cambiarlo desde Ajustes del Sistema sin pasar por toc.
     */
    func refreshLogin() {
        loginEnabled = LoginItem.isEnabled
        loginPending = LoginItem.needsApproval
    }
}
