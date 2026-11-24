/*
-------------------------------------------------------------------------------
Name:     Sources/TocCore/WindowAction.swift
Purpose:  Catálogo de acciones de colocación de ventanas de toc, con su
          nombre visible, su grupo en el menú y su atajo por defecto.
Version:  v0.0.2
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

/// Acción que coloca la ventana activa en una zona de la pantalla.
public enum WindowAction: String, CaseIterable, Sendable {
    case leftHalf, rightHalf, centerHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case firstThird, centerThird, lastThird, firstTwoThirds, centerTwoThirds, lastTwoThirds
    case topLeftSixth, topCenterSixth, topRightSixth, bottomLeftSixth, bottomCenterSixth, bottomRightSixth
    case maximize, almostMaximize, maximizeHeight, center, restore
    case nextDisplay, previousDisplay

    /// Nombre que se muestra en el menú.
    public var title: String {
        switch self {
        case .leftHalf: "Mitad izquierda"
        case .rightHalf: "Mitad derecha"
        case .centerHalf: "Mitad central"
        case .topHalf: "Mitad superior"
        case .bottomHalf: "Mitad inferior"
        case .topLeft: "Arriba a la izquierda"
        case .topRight: "Arriba a la derecha"
        case .bottomLeft: "Abajo a la izquierda"
        case .bottomRight: "Abajo a la derecha"
        case .firstThird: "Primer tercio"
        case .centerThird: "Tercio central"
        case .lastThird: "Último tercio"
        case .firstTwoThirds: "Primeros dos tercios"
        case .centerTwoThirds: "Dos tercios centrales"
        case .lastTwoThirds: "Últimos dos tercios"
        case .topLeftSixth: "Tercio arriba a la izquierda"
        case .topCenterSixth: "Tercio central arriba"
        case .topRightSixth: "Tercio arriba a la derecha"
        case .bottomLeftSixth: "Tercio abajo a la izquierda"
        case .bottomCenterSixth: "Tercio central abajo"
        case .bottomRightSixth: "Tercio abajo a la derecha"
        case .maximize: "Maximizar"
        case .almostMaximize: "Casi maximizar"
        case .maximizeHeight: "Maximizar altura"
        case .center: "Centrar"
        case .restore: "Restaurar"
        case .nextDisplay: "Pantalla siguiente"
        case .previousDisplay: "Pantalla anterior"
        }
    }

    /// Grupo del menú; entre grupos distintos se dibuja un separador.
    public var group: Int {
        switch self {
        case .leftHalf, .rightHalf, .centerHalf, .topHalf, .bottomHalf: 0
        case .topLeft, .topRight, .bottomLeft, .bottomRight: 1
        case .firstThird, .centerThird, .lastThird, .firstTwoThirds, .centerTwoThirds, .lastTwoThirds,
             .topLeftSixth, .topCenterSixth, .topRightSixth,
             .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth: 2
        case .maximize, .almostMaximize, .maximizeHeight, .center, .restore: 3
        case .nextDisplay, .previousDisplay: 4
        }
    }

    /// Nombre de cada grupo, para las secciones de las preferencias.
    public static func groupTitle(_ group: Int) -> String {
        switch group {
        case 0: "Mitades"
        case 1: "Cuartos"
        case 2: "Tercios"
        case 3: "Tamaño"
        default: "Pantallas"
        }
    }

    /// Atajo por defecto, o nil si no tiene. Son los mismos que usa Rectangle;
    /// los tercios de media altura (que Rectangle deja sin atajo) usan ⌃⌥⇧ con
    /// la rejilla U I O / J K L del teclado.
    public var defaultShortcut: Shortcut? {
        typealias K = Shortcut.KeyCode
        let ctrlOpt: Shortcut.Modifiers = [.control, .option]
        let key: UInt32
        var modifiers = ctrlOpt
        switch self {
        case .leftHalf: key = K.leftArrow
        case .rightHalf: key = K.rightArrow
        case .topHalf: key = K.upArrow
        case .bottomHalf: key = K.downArrow
        case .topLeft: key = K.u
        case .topRight: key = K.i
        case .bottomLeft: key = K.j
        case .bottomRight: key = K.k
        case .firstThird: key = K.d
        case .centerThird: key = K.f
        case .lastThird: key = K.g
        case .firstTwoThirds: key = K.e
        case .lastTwoThirds: key = K.t
        case .topLeftSixth: key = K.u; modifiers.insert(.shift)
        case .topCenterSixth: key = K.i; modifiers.insert(.shift)
        case .topRightSixth: key = K.o; modifiers.insert(.shift)
        case .bottomLeftSixth: key = K.j; modifiers.insert(.shift)
        case .bottomCenterSixth: key = K.k; modifiers.insert(.shift)
        case .bottomRightSixth: key = K.l; modifiers.insert(.shift)
        case .maximize: key = K.returnKey
        case .maximizeHeight: key = K.upArrow; modifiers.insert(.shift)
        case .center: key = K.c
        case .restore: key = K.delete
        case .nextDisplay: key = K.rightArrow; modifiers.insert(.command)
        case .previousDisplay: key = K.leftArrow; modifiers.insert(.command)
        case .centerHalf, .centerTwoThirds, .almostMaximize: return nil
        }
        return Shortcut(keyCode: key, modifiers: modifiers)
    }
}
