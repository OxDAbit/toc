/*
-------------------------------------------------------------------------------
Name:     Tests/TocCoreTests/PreferencesTests.swift
Purpose:  Tests de las preferencias: atajos personalizados, conflictos entre
          acciones, restablecer, visibilidad en el menú y codificación JSON.
Version:  v0.0.2
Author:   David Alvarez Medina aka 0xDA_bit
Created:  24/11/2026
-------------------------------------------------------------------------------
*/

import Foundation
import XCTest
@testable import TocCore

final class PreferencesTests: XCTestCase {

    let hyperL = Shortcut(keyCode: 37, modifiers: [.control, .option, .command])

    /**
     * @brief  Sin cambios, cada acción usa su atajo por defecto.
     */
    func testDefaults() {
        let prefs = TocPreferences()
        XCTAssertEqual(prefs.shortcut(for: .leftHalf), WindowAction.leftHalf.defaultShortcut)
        XCTAssertNil(prefs.shortcut(for: .almostMaximize))
        XCTAssertFalse(prefs.isCustomized(.leftHalf))
        XCTAssertTrue(WindowAction.allCases.allSatisfy(prefs.isVisible))
    }

    /**
     * @brief  Un atajo personalizado sustituye al de por defecto y se puede restablecer.
     */
    func testCustomShortcutAndReset() {
        var prefs = TocPreferences()
        prefs.setShortcut(hyperL, for: .leftHalf)
        XCTAssertEqual(prefs.shortcut(for: .leftHalf), hyperL)
        XCTAssertTrue(prefs.isCustomized(.leftHalf))
        prefs.reset(.leftHalf)
        XCTAssertEqual(prefs.shortcut(for: .leftHalf), WindowAction.leftHalf.defaultShortcut)
        XCTAssertTrue(prefs.customShortcuts.isEmpty)
    }

    /**
     * @brief  Asignar un atajo en uso se lo quita a la otra acción.
     */
    func testConflictDisplacesOtherAction() throws {
        var prefs = TocPreferences()
        let rightArrow = try XCTUnwrap(WindowAction.rightHalf.defaultShortcut)
        let displaced = prefs.setShortcut(rightArrow, for: .almostMaximize)
        XCTAssertEqual(displaced, [.rightHalf])
        XCTAssertNil(prefs.shortcut(for: .rightHalf))
        XCTAssertEqual(prefs.shortcut(for: .almostMaximize), rightArrow)
        let shortcuts = prefs.activeShortcuts().map(\.shortcut)
        XCTAssertEqual(shortcuts.count, Set(shortcuts).count)
    }

    /**
     * @brief  Quitar el atajo de una acción y restablecerlos todos.
     */
    func testClearAndResetAll() {
        var prefs = TocPreferences()
        prefs.setShortcut(nil, for: .maximize)
        XCTAssertNil(prefs.shortcut(for: .maximize))
        XCTAssertTrue(prefs.isCustomized(.maximize))
        prefs.setShortcut(hyperL, for: .center)
        prefs.resetAllShortcuts()
        XCTAssertEqual(prefs, TocPreferences())
    }

    /**
     * @brief  Ocultar una acción del menú no le quita el atajo.
     */
    func testVisibility() {
        var prefs = TocPreferences()
        prefs.setVisible(false, for: .centerThird)
        XCTAssertFalse(prefs.isVisible(.centerThird))
        XCTAssertNotNil(prefs.shortcut(for: .centerThird))
        prefs.setVisible(true, for: .centerThird)
        XCTAssertTrue(prefs.isVisible(.centerThird))
    }

    /**
     * @brief  Las preferencias se guardan y se recuperan en JSON sin perder nada.
     */
    func testCodableRoundTrip() throws {
        var prefs = TocPreferences()
        prefs.setShortcut(hyperL, for: .leftHalf)
        prefs.setShortcut(nil, for: .restore)
        prefs.setVisible(false, for: .topHalf)
        let data = try JSONEncoder().encode(prefs)
        XCTAssertEqual(try JSONDecoder().decode(TocPreferences.self, from: data), prefs)
    }

    /**
     * @brief  Un atajo global necesita ⌃, ⌥ o ⌘ y una tecla conocida.
     */
    func testValidGlobalShortcut() {
        XCTAssertTrue(hyperL.isValidGlobal)
        XCTAssertFalse(Shortcut(keyCode: 37, modifiers: [.shift]).isValidGlobal)
        XCTAssertFalse(Shortcut(keyCode: 37, modifiers: []).isValidGlobal)
        XCTAssertFalse(Shortcut(keyCode: 200, modifiers: [.control]).isValidGlobal)
        XCTAssertEqual(hyperL.display, "⌃⌥⌘L")
    }
}
