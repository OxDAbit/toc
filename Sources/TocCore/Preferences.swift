/*
-------------------------------------------------------------------------------
Name:     Sources/TocCore/Preferences.swift
Purpose:  Preferencias de toc que el usuario puede cambiar: atajo de cada
          acción y acciones visibles en el menú. Solo guarda lo que difiere
          de los valores por defecto, para que una versión nueva con atajos
          nuevos no pise lo que el usuario ya cambió. Lógica pura, sin AppKit.
Version:  v0.0.2
Author:   David Alvarez Medina aka 0xDA_bit
Created:  24/11/2026
-------------------------------------------------------------------------------
*/

/// Preferencias de atajos y visibilidad del menú.
public struct TocPreferences: Codable, Equatable, Sendable {

    /// Atajos que el usuario ha cambiado, por identificador de acción.
    public var customShortcuts: [String: Shortcut] = [:]
    /// Acciones a las que el usuario ha quitado el atajo.
    public var clearedShortcuts: Set<String> = []
    /// Acciones que el usuario ha ocultado del menú.
    public var hiddenActions: Set<String> = []

    /**
     * @brief  Crea unas preferencias con todos los valores por defecto.
     */
    public init() {}

    /**
     * @brief  Devuelve el atajo vigente de una acción.
     *
     * @param[in]  action  Acción.
     * @return Atajo del usuario, el de por defecto, o nil si no tiene.
     */
    public func shortcut(for action: WindowAction) -> Shortcut? {
        if clearedShortcuts.contains(action.rawValue) { return nil }
        return customShortcuts[action.rawValue] ?? action.defaultShortcut
    }

    /**
     * @brief  Indica si el atajo de una acción difiere del de por defecto.
     *
     * @param[in]  action  Acción.
     * @return true si el usuario lo ha cambiado o quitado.
     */
    public func isCustomized(_ action: WindowAction) -> Bool {
        shortcut(for: action) != action.defaultShortcut
    }

    /**
     * @brief  Asigna un atajo a una acción, o se lo quita.
     *
     * Si otra acción ya usaba ese atajo, se le quita para que no haya dos
     * acciones con el mismo.
     *
     * @param[in]  shortcut  Atajo nuevo, o nil para dejar la acción sin atajo.
     * @param[in]  action    Acción.
     * @return Acciones que han perdido su atajo por el cambio.
     */
    @discardableResult
    public mutating func setShortcut(_ shortcut: Shortcut?, for action: WindowAction) -> [WindowAction] {
        let key = action.rawValue
        guard let shortcut else {
            customShortcuts[key] = nil
            if action.defaultShortcut == nil {
                clearedShortcuts.remove(key)
            } else {
                clearedShortcuts.insert(key)
            }
            return []
        }
        var displaced: [WindowAction] = []
        for other in WindowAction.allCases where other != action && self.shortcut(for: other) == shortcut {
            setShortcut(nil, for: other)
            displaced.append(other)
        }
        clearedShortcuts.remove(key)
        customShortcuts[key] = shortcut == action.defaultShortcut ? nil : shortcut
        return displaced
    }

    /**
     * @brief  Devuelve una acción a su atajo por defecto.
     *
     * @param[in]  action  Acción.
     * @return Acciones que han perdido su atajo por el cambio.
     */
    @discardableResult
    public mutating func reset(_ action: WindowAction) -> [WindowAction] {
        if let shortcut = action.defaultShortcut {
            return setShortcut(shortcut, for: action)
        }
        customShortcuts[action.rawValue] = nil
        clearedShortcuts.remove(action.rawValue)
        return []
    }

    /**
     * @brief  Devuelve todos los atajos a sus valores por defecto.
     */
    public mutating func resetAllShortcuts() {
        customShortcuts.removeAll()
        clearedShortcuts.removeAll()
    }

    /**
     * @brief  Indica si una acción aparece en el menú.
     *
     * @param[in]  action  Acción.
     * @return true si está visible.
     */
    public func isVisible(_ action: WindowAction) -> Bool {
        !hiddenActions.contains(action.rawValue)
    }

    /**
     * @brief  Muestra u oculta una acción en el menú.
     *
     * Ocultar una acción no le quita el atajo.
     *
     * @param[in]  visible  true para mostrarla.
     * @param[in]  action   Acción.
     */
    public mutating func setVisible(_ visible: Bool, for action: WindowAction) {
        if visible {
            hiddenActions.remove(action.rawValue)
        } else {
            hiddenActions.insert(action.rawValue)
        }
    }

    /**
     * @brief  Devuelve las acciones que tienen atajo, con el atajo vigente.
     *
     * @return Pares (acción, atajo) en el orden del catálogo.
     */
    public func activeShortcuts() -> [(action: WindowAction, shortcut: Shortcut)] {
        WindowAction.allCases.compactMap { action in shortcut(for: action).map { (action, $0) } }
    }
}
