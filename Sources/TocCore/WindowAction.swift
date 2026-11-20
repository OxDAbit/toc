/*
-------------------------------------------------------------------------------
Name:     Sources/TocCore/WindowAction.swift
Purpose:  Catálogo de acciones de colocación de ventanas de toc, con su
          nombre visible, su grupo en el menú y su atajo por defecto.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

/// Acción que coloca la ventana activa en una zona de la pantalla.
public enum WindowAction: String, CaseIterable, Sendable {
    case leftHalf, rightHalf, centerHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case firstThird, centerThird, lastThird, firstTwoThirds, centerTwoThirds, lastTwoThirds
    case maximize, almostMaximize, maximizeHeight, center, restore

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
        case .maximize: "Maximizar"
        case .almostMaximize: "Casi maximizar"
        case .maximizeHeight: "Maximizar altura"
        case .center: "Centrar"
        case .restore: "Restaurar"
        }
    }

    /// Grupo del menú; entre grupos distintos se dibuja un separador.
    public var group: Int {
        switch self {
        case .leftHalf, .rightHalf, .centerHalf, .topHalf, .bottomHalf: 0
        case .topLeft, .topRight, .bottomLeft, .bottomRight: 1
        case .firstThird, .centerThird, .lastThird, .firstTwoThirds, .centerTwoThirds, .lastTwoThirds: 2
        case .maximize, .almostMaximize, .maximizeHeight, .center, .restore: 3
        }
    }

    /// Atajo por defecto (los mismos que usa Rectangle), o nil si no tiene.
    public var defaultShortcut: Shortcut? {
        let ctrlOpt: Shortcut.Modifiers = [.control, .option]
        switch self {
        case .leftHalf: return Shortcut(key: .leftArrow, modifiers: ctrlOpt)
        case .rightHalf: return Shortcut(key: .rightArrow, modifiers: ctrlOpt)
        case .topHalf: return Shortcut(key: .upArrow, modifiers: ctrlOpt)
        case .bottomHalf: return Shortcut(key: .downArrow, modifiers: ctrlOpt)
        case .topLeft: return Shortcut(key: .u, modifiers: ctrlOpt)
        case .topRight: return Shortcut(key: .i, modifiers: ctrlOpt)
        case .bottomLeft: return Shortcut(key: .j, modifiers: ctrlOpt)
        case .bottomRight: return Shortcut(key: .k, modifiers: ctrlOpt)
        case .firstThird: return Shortcut(key: .d, modifiers: ctrlOpt)
        case .centerThird: return Shortcut(key: .f, modifiers: ctrlOpt)
        case .lastThird: return Shortcut(key: .g, modifiers: ctrlOpt)
        case .firstTwoThirds: return Shortcut(key: .e, modifiers: ctrlOpt)
        case .lastTwoThirds: return Shortcut(key: .t, modifiers: ctrlOpt)
        case .maximize: return Shortcut(key: .returnKey, modifiers: ctrlOpt)
        case .maximizeHeight: return Shortcut(key: .upArrow, modifiers: [.control, .option, .shift])
        case .center: return Shortcut(key: .c, modifiers: ctrlOpt)
        case .restore: return Shortcut(key: .delete, modifiers: ctrlOpt)
        case .centerHalf, .centerTwoThirds, .almostMaximize: return nil
        }
    }
}
