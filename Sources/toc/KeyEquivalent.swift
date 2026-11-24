/*
-------------------------------------------------------------------------------
Name:     Sources/toc/KeyEquivalent.swift
Purpose:  Traducción de un atajo de toc al formato de AppKit: el nombre de la
          tecla según la distribución de teclado activa (español, inglés…),
          el carácter y los modificadores que NSMenuItem usa para mostrarlo
          en el menú, y los modificadores de un NSEvent al formato de toc.
Version:  v0.0.2
Author:   David Alvarez Medina aka 0xDA_bit
Created:  24/11/2026
-------------------------------------------------------------------------------
*/

import AppKit
import Carbon
import TocCore

enum KeyEquivalent {

    /// Teclas especiales: código virtual → carácter de función de AppKit.
    private static let functionKeys: [UInt32: Int] = [
        123: NSLeftArrowFunctionKey, 124: NSRightArrowFunctionKey,
        125: NSDownArrowFunctionKey, 126: NSUpArrowFunctionKey,
        115: NSHomeFunctionKey, 119: NSEndFunctionKey,
        116: NSPageUpFunctionKey, 121: NSPageDownFunctionKey, 117: NSDeleteFunctionKey,
        122: NSF1FunctionKey, 120: NSF2FunctionKey, 99: NSF3FunctionKey, 118: NSF4FunctionKey,
        96: NSF5FunctionKey, 97: NSF6FunctionKey, 98: NSF7FunctionKey, 100: NSF8FunctionKey,
        101: NSF9FunctionKey, 109: NSF10FunctionKey, 103: NSF11FunctionKey, 111: NSF12FunctionKey,
        105: NSF13FunctionKey, 107: NSF14FunctionKey, 113: NSF15FunctionKey
    ]

    /// Teclas de control: código virtual → carácter.
    private static let controlKeys: [UInt32: String] = [
        36: "\r", 48: "\t", 49: " ", 51: "\u{8}", 53: "\u{1b}"
    ]

    /**
     * @brief  Indica si una tecla es especial (flechas, F1…, ↩, ⌫…), cuyo nombre no depende del teclado.
     *
     * @param[in]  keyCode  Código virtual de la tecla.
     * @return true si es una tecla especial.
     */
    static func isSpecial(_ keyCode: UInt32) -> Bool {
        functionKeys[keyCode] != nil || controlKeys[keyCode] != nil
    }

    /**
     * @brief  Devuelve el carácter que produce una tecla con la distribución de teclado activa.
     *
     * Usa UCKeyTranslate sin modificadores ni teclas muertas: con el teclado
     * español, el código 41 da «ñ» en lugar del «;» del teclado de EE. UU.
     *
     * @param[in]  keyCode  Código virtual de la tecla.
     * @return Carácter en minúscula, o nil si la tecla no produce ninguno visible.
     */
    static func layoutCharacter(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
                ?? TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = layoutData.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                                  UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                  &deadKeyState, characters.count, &length, &characters)
        }
        guard status == noErr, length > 0 else { return nil }
        let text = String(utf16CodeUnits: characters, count: length)
        return text.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters)).isEmpty ? nil : text
    }

    /**
     * @brief  Devuelve el nombre visible de una tecla según la distribución de teclado activa.
     *
     * @param[in]  keyCode  Código virtual de la tecla.
     * @return Nombre de la tecla (en mayúscula si es una letra).
     */
    static func keyName(for keyCode: UInt32) -> String {
        if !isSpecial(keyCode), let character = layoutCharacter(for: keyCode) {
            return character.uppercased()
        }
        return KeyNames.name(for: keyCode)
    }

    /**
     * @brief  Representación legible de un atajo con la distribución de teclado activa.
     *
     * @param[in]  shortcut  Atajo.
     * @return Texto como «⌃⌥Ñ».
     */
    static func display(_ shortcut: Shortcut) -> String {
        shortcut.modifiers.symbols + keyName(for: shortcut.keyCode)
    }

    /**
     * @brief  Devuelve el carácter con el que NSMenuItem muestra una tecla.
     *
     * @param[in]  keyCode  Código virtual de la tecla.
     * @return Carácter de equivalente de teclado, o nil si no se puede mostrar.
     */
    static func character(for keyCode: UInt32) -> String? {
        if let scalar = functionKeys[keyCode], let unicode = UnicodeScalar(scalar) {
            return String(Character(unicode))
        }
        if let control = controlKeys[keyCode] { return control }
        if let character = layoutCharacter(for: keyCode) { return character.lowercased() }
        let name = KeyNames.name(for: keyCode)
        return KeyNames.isKnown(keyCode) && name.count == 1 ? name.lowercased() : nil
    }

    /**
     * @brief  Convierte los modificadores de toc al formato de NSMenuItem.
     *
     * @param[in]  modifiers  Modificadores del atajo.
     * @return Máscara de modificadores de AppKit.
     */
    static func mask(_ modifiers: Shortcut.Modifiers) -> NSEvent.ModifierFlags {
        var mask: NSEvent.ModifierFlags = []
        if modifiers.contains(.control) { mask.insert(.control) }
        if modifiers.contains(.option) { mask.insert(.option) }
        if modifiers.contains(.shift) { mask.insert(.shift) }
        if modifiers.contains(.command) { mask.insert(.command) }
        return mask
    }

    /**
     * @brief  Convierte los modificadores de un evento de teclado al formato de toc.
     *
     * @param[in]  flags  Modificadores del NSEvent.
     * @return Modificadores de toc.
     */
    static func modifiers(from flags: NSEvent.ModifierFlags) -> Shortcut.Modifiers {
        var modifiers: Shortcut.Modifiers = []
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.command) { modifiers.insert(.command) }
        return modifiers
    }

    /**
     * @brief  Aplica un atajo a un elemento del menú para que lo muestre.
     *
     * @param[in]  shortcut  Atajo, o nil para que no muestre ninguno.
     * @param[in]  item      Elemento del menú.
     */
    @MainActor
    static func apply(_ shortcut: Shortcut?, to item: NSMenuItem) {
        guard let shortcut, let character = character(for: shortcut.keyCode) else {
            item.keyEquivalent = ""
            item.keyEquivalentModifierMask = []
            return
        }
        item.keyEquivalent = character
        item.keyEquivalentModifierMask = mask(shortcut.modifiers)
    }
}
