/*
-------------------------------------------------------------------------------
Name:     Sources/TocCore/Shortcut.swift
Purpose:  Atajo de teclado independiente de AppKit y Carbon: código virtual de
          tecla de macOS (kVK_*) más modificadores, con su conversión a la
          máscara de Carbon, su representación legible y su codificación para
          guardarlo en las preferencias.
Version:  v0.0.2
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

/// Combinación de tecla y modificadores.
public struct Shortcut: Hashable, Codable, Sendable {

    /// Códigos virtuales de las teclas que usan los atajos por defecto (kVK_*).
    public enum KeyCode {
        public static let d: UInt32 = 2, f: UInt32 = 3, g: UInt32 = 5, c: UInt32 = 8
        public static let e: UInt32 = 14, t: UInt32 = 17
        public static let u: UInt32 = 32, i: UInt32 = 34, o: UInt32 = 31
        public static let j: UInt32 = 38, k: UInt32 = 40, l: UInt32 = 37
        public static let returnKey: UInt32 = 36, tab: UInt32 = 48, space: UInt32 = 49
        public static let delete: UInt32 = 51, escape: UInt32 = 53
        public static let leftArrow: UInt32 = 123, rightArrow: UInt32 = 124
        public static let downArrow: UInt32 = 125, upArrow: UInt32 = 126
    }

    /// Modificadores del atajo.
    public struct Modifiers: OptionSet, Hashable, Codable, Sendable {
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

    /// Código virtual de la tecla (kVK_*), independiente de la distribución del teclado.
    public let keyCode: UInt32
    public let modifiers: Modifiers

    /**
     * @brief  Crea un atajo.
     *
     * @param[in]  keyCode    Código virtual de la tecla.
     * @param[in]  modifiers  Modificadores que deben estar pulsados.
     */
    public init(keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Representación legible, por ejemplo "⌃⌥←".
    public var display: String { modifiers.symbols + KeyNames.name(for: keyCode) }

    /// Si sirve como atajo global: necesita ⌃, ⌥ o ⌘ (⇧ solo no basta) y una tecla conocida.
    public var isValidGlobal: Bool {
        !modifiers.intersection([.control, .option, .command]).isEmpty && KeyNames.isKnown(keyCode)
    }
}

/// Nombres de las teclas según su código virtual, con la disposición de EE. UU.
/// La app los sustituye por los de la distribución de teclado activa (ver
/// KeyEquivalent.keyName); esta tabla es la referencia y el respaldo.
public enum KeyNames {

    /// Tabla de código virtual → nombre visible.
    static let table: [UInt32: String] = [
        10: "§", 0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Espacio", 50: "`", 51: "⌫", 53: "⎋",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        105: "F13", 107: "F14", 109: "F10", 111: "F12", 113: "F15",
        115: "↖", 116: "⇞", 117: "⌦", 118: "F4", 119: "↘", 120: "F2", 121: "⇟", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ]

    /**
     * @brief  Devuelve el nombre visible de una tecla.
     *
     * @param[in]  keyCode  Código virtual de la tecla.
     * @return Nombre de la tecla, o «#código» si no está en la tabla.
     */
    public static func name(for keyCode: UInt32) -> String {
        table[keyCode] ?? "#\(keyCode)"
    }

    /**
     * @brief  Indica si una tecla está en la tabla de teclas conocidas.
     *
     * @param[in]  keyCode  Código virtual de la tecla.
     * @return true si toc sabe mostrarla.
     */
    public static func isKnown(_ keyCode: UInt32) -> Bool {
        table[keyCode] != nil
    }
}
