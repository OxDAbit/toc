/*
-------------------------------------------------------------------------------
Name:     Sources/toc/StatusMenuController.swift
Purpose:  Icono y menú de toc en la barra de menús: estado de Accesibilidad,
          acciones con sus atajos, comprobación manual, copia del
          diagnóstico y salida.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit
import TocCore

@MainActor
final class StatusMenuController: NSObject {

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let statusLine = NSMenuItem()
    private let statusDetail = NSMenuItem()
    private let hotkeyWarning = NSMenuItem()
    private let snapItem = NSMenuItem()
    private let loginItem = NSMenuItem()

    private let onAction: (WindowAction) -> Void
    private let onToggleSnap: () -> Void
    private let onToggleLogin: () -> Void
    private let onCheck: () -> Void
    private let onCopyDiagnostics: () -> Void

    /**
     * @brief  Crea el icono y el menú.
     *
     * @param[in]  onAction           Se llama al elegir una acción.
     * @param[in]  onToggleSnap       Se llama al activar o desactivar el ajuste al arrastrar.
     * @param[in]  onToggleLogin      Se llama al activar o desactivar la apertura al iniciar sesión.
     * @param[in]  onCheck            Se llama al pedir una comprobación de Accesibilidad.
     * @param[in]  onCopyDiagnostics  Se llama al pedir el diagnóstico.
     */
    init(onAction: @escaping (WindowAction) -> Void,
         onToggleSnap: @escaping () -> Void,
         onToggleLogin: @escaping () -> Void,
         onCheck: @escaping () -> Void,
         onCopyDiagnostics: @escaping () -> Void) {
        self.onAction = onAction
        self.onToggleSnap = onToggleSnap
        self.onToggleLogin = onToggleLogin
        self.onCheck = onCheck
        self.onCopyDiagnostics = onCopyDiagnostics
        super.init()
        buildMenu()
        item.menu = menu
        update(health: .unknown)
    }

    /**
     * @brief  Construye el menú completo.
     */
    private func buildMenu() {
        statusLine.isEnabled = false
        statusDetail.isEnabled = false
        statusDetail.isHidden = true
        hotkeyWarning.isEnabled = false
        hotkeyWarning.isHidden = true
        menu.addItem(statusLine)
        menu.addItem(statusDetail)
        menu.addItem(hotkeyWarning)

        var lastGroup = -1
        for action in WindowAction.allCases {
            if action.group != lastGroup {
                menu.addItem(.separator())
                lastGroup = action.group
            }
            let entry = NSMenuItem(title: action.title, action: #selector(actionSelected(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = action.rawValue
            entry.image = MenuIcon.image(for: action)
            if let shortcut = action.defaultShortcut {
                entry.keyEquivalent = Self.keyEquivalent(shortcut.key)
                entry.keyEquivalentModifierMask = Self.modifierMask(shortcut.modifiers)
            }
            menu.addItem(entry)
        }

        menu.addItem(.separator())
        snapItem.title = "Ajustar al arrastrar a los bordes"
        snapItem.action = #selector(snapSelected)
        snapItem.target = self
        menu.addItem(snapItem)
        loginItem.title = "Abrir al iniciar sesión"
        loginItem.action = #selector(loginSelected)
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())
        let check = NSMenuItem(title: "Comprobar Accesibilidad", action: #selector(checkSelected), keyEquivalent: "")
        check.target = self
        menu.addItem(check)
        let copy = NSMenuItem(title: "Copiar diagnóstico", action: #selector(copySelected), keyEquivalent: "")
        copy.target = self
        menu.addItem(copy)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Salir de toc", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    /**
     * @brief  Actualiza el icono y la línea de estado según la salud de Accesibilidad.
     *
     * @param[in]  health  Estado actual.
     */
    func update(health: AXHealth) {
        let symbol: String
        statusDetail.isHidden = true
        switch health {
        case .healthy, .unknown:
            symbol = ""
            statusLine.title = health == .healthy ? "Accesibilidad: correcta" : "Accesibilidad: sin comprobar"
        case .broken:
            symbol = "exclamationmark.triangle"
            statusLine.title = "⚠︎ macOS ha perdido el acceso a las ventanas"
            statusDetail.title = "Solo se pueden mover apps scriptables. Reinicia el Mac para recuperarlo."
            statusDetail.isHidden = false
        case .permissionMissing:
            symbol = "lock.slash"
            statusLine.title = "⚠︎ Falta el permiso de Accesibilidad"
            statusDetail.title = "Ajustes del Sistema → Privacidad y seguridad → Accesibilidad"
            statusDetail.isHidden = false
        }
        // En estado normal se muestra el logo de toc; en los avisos, un símbolo del sistema.
        let image = symbol.isEmpty
            ? MenuIcon.statusLogo()
            : NSImage(systemSymbolName: symbol, accessibilityDescription: "toc")
        image?.isTemplate = true
        item.button?.image = image
    }

    /**
     * @brief  Muestra en el menú los atajos que no se pudieron registrar.
     *
     * @param[in]  failed  Descripción de los atajos ocupados.
     */
    func update(failedHotkeys failed: [String]) {
        hotkeyWarning.isHidden = failed.isEmpty
        hotkeyWarning.title = "Atajos ocupados por otra app: \(failed.count)"
        hotkeyWarning.toolTip = failed.joined(separator: "\n")
    }

    /**
     * @brief  Marca o desmarca las opciones del menú.
     *
     * @param[in]  snapEnabled   Si el ajuste al arrastrar está activo.
     * @param[in]  loginEnabled  Si toc se abre al iniciar sesión.
     * @param[in]  loginPending  Si macOS espera la aprobación del usuario.
     */
    func update(snapEnabled: Bool, loginEnabled: Bool, loginPending: Bool) {
        snapItem.state = snapEnabled ? .on : .off
        loginItem.state = loginEnabled ? .on : (loginPending ? .mixed : .off)
        loginItem.toolTip = loginPending
            ? "Pendiente de aprobar en Ajustes del Sistema → General → Ítems de inicio de sesión"
            : nil
    }

    /**
     * @brief  Atiende el cambio del ajuste al arrastrar.
     */
    @objc private func snapSelected() {
        onToggleSnap()
    }

    /**
     * @brief  Atiende el cambio de la apertura al iniciar sesión.
     */
    @objc private func loginSelected() {
        onToggleLogin()
    }

    /**
     * @brief  Atiende la elección de una acción del menú.
     *
     * @param[in]  sender  Elemento del menú elegido.
     */
    @objc private func actionSelected(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = WindowAction(rawValue: raw) else { return }
        onAction(action)
    }

    /**
     * @brief  Atiende la petición de comprobar Accesibilidad.
     */
    @objc private func checkSelected() {
        onCheck()
    }

    /**
     * @brief  Atiende la petición de copiar el diagnóstico.
     */
    @objc private func copySelected() {
        onCopyDiagnostics()
    }

    /**
     * @brief  Convierte una tecla en el carácter que NSMenuItem usa para mostrarla.
     *
     * @param[in]  key  Tecla del atajo.
     * @return Carácter de equivalente de teclado.
     */
    private static func keyEquivalent(_ key: Shortcut.Key) -> String {
        let scalar: Int
        switch key {
        case .leftArrow: scalar = NSLeftArrowFunctionKey
        case .rightArrow: scalar = NSRightArrowFunctionKey
        case .upArrow: scalar = NSUpArrowFunctionKey
        case .downArrow: scalar = NSDownArrowFunctionKey
        case .returnKey: return "\r"
        case .delete: return "\u{8}"
        default: return key.symbol.lowercased()
        }
        return String(Character(UnicodeScalar(scalar)!))
    }

    /**
     * @brief  Convierte los modificadores al formato de NSMenuItem.
     *
     * @param[in]  modifiers  Modificadores del atajo.
     * @return Máscara de modificadores de AppKit.
     */
    private static func modifierMask(_ modifiers: Shortcut.Modifiers) -> NSEvent.ModifierFlags {
        var mask: NSEvent.ModifierFlags = []
        if modifiers.contains(.control) { mask.insert(.control) }
        if modifiers.contains(.option) { mask.insert(.option) }
        if modifiers.contains(.shift) { mask.insert(.shift) }
        if modifiers.contains(.command) { mask.insert(.command) }
        return mask
    }
}
