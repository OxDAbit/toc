/*
-------------------------------------------------------------------------------
Name:     Sources/TocCore/Shortcut.swift
Purpose:  Atajo de teclado independiente de AppKit y Carbon: tecla física
          (código virtual de macOS) más modificadores, con su conversión a
          la máscara de Carbon y su representación legible.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

/// Combinación de tecla y modificadores.
public struct Shortcut: Hashable, Sendable {

    /// Teclas usadas por los atajos por defecto, con su código virtual (kVK_*).
    public enum Key: UInt32, Sendable {
        case d = 2, f = 3, g = 5, c = 8, e = 14, t = 17
        case u = 32, i = 34, j = 38, k = 40
        case returnKey = 36, delete = 51
        case leftArrow = 123, rightArrow = 124, downArrow = 125, upArrow = 126

        /// Símbolo con el que se muestra la tecla.
        public var symbol: String {
            switch self {
            case .d: "D"
            case .f: "F"
            case .g: "G"
            case .c: "C"
            case .e: "E"
            case .t: "T"
            case .u: "U"
            case .i: "I"
            case .j: "J"
            case .k: "K"
            case .returnKey: "↩"
            case .delete: "⌫"
            case .leftArrow: "←"
            case .rightArrow: "→"
            case .downArrow: "↓"
            case .upArrow: "↑"
            }
        }
    }

    /// Modificadores del atajo.
    public struct Modifiers: OptionSet, Hashable, Sendable {
        public let rawValue: UInt8

        /**
         * @brief  Crea el conjunto a partir de su valor bruto.
         *
         * @param[in]  rawValue  Máscara de bits de los modificadores.
         */
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)

        /// Máscara equivalente de Carbon (controlKey, optionKey, shiftKey, cmdKey).
        public var carbonFlags: UInt32 {
            var flags: UInt32 = 0
            if contains(.command) { flags |= 0x0100 }
            if contains(.shift) { flags |= 0x0200 }
            if contains(.option) { flags |= 0x0800 }
            if contains(.control) { flags |= 0x1000 }
            return flags
        }

        /// Símbolos en el orden estándar de macOS (⌃⌥⇧⌘).
        public var symbols: String {
            var text = ""
            if contains(.control) { text += "⌃" }
            if contains(.option) { text += "⌥" }
            if contains(.shift) { text += "⇧" }
            if contains(.command) { text += "⌘" }
            return text
        }
    }

    public let key: Key
    public let modifiers: Modifiers

    /**
     * @brief  Crea un atajo.
     *
     * @param[in]  key        Tecla física.
     * @param[in]  modifiers  Modificadores que deben estar pulsados.
     */
    public init(key: Key, modifiers: Modifiers) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Representación legible, por ejemplo "⌃⌥←".
    public var display: String { modifiers.symbols + key.symbol }
}
