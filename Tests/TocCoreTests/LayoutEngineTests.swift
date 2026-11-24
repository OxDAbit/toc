/*
-------------------------------------------------------------------------------
Name:     Tests/TocCoreTests/LayoutEngineTests.swift
Purpose:  Tests del motor de posiciones con la geometría real del monitor
          C34H89x (3440×1440, zona útil 3440×1352 bajo la barra de menús).
Version:  v0.0.2
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import CoreGraphics
import XCTest
@testable import TocCore

final class LayoutEngineTests: XCTestCase {

    /// Zona útil del C34H89x en coordenadas de Accesibilidad: 30 px de barra de
    /// menús arriba y 58 px de Dock abajo.
    let visible = CGRect(x: 0, y: 30, width: 3440, height: 1352)
    let window = CGRect(x: 506, y: 307, width: 920, height: 624)

    /**
     * @brief  Atajo para calcular el marco de una acción con la ventana y pantalla de prueba.
     *
     * @param[in]  action  Acción a calcular.
     * @return Marco de destino.
     */
    func frame(_ action: WindowAction) -> CGRect? {
        LayoutEngine.frame(for: action, window: window, visible: visible)
    }

    /**
     * @brief  Comprueba las mitades izquierda y derecha, que deben coincidir con lo que hace Rectangle.
     */
    func testHalves() {
        XCTAssertEqual(frame(.leftHalf), CGRect(x: 0, y: 30, width: 1720, height: 1352))
        XCTAssertEqual(frame(.rightHalf), CGRect(x: 1720, y: 30, width: 1720, height: 1352))
        XCTAssertEqual(frame(.topHalf), CGRect(x: 0, y: 30, width: 3440, height: 676))
        XCTAssertEqual(frame(.bottomHalf), CGRect(x: 0, y: 706, width: 3440, height: 676))
        XCTAssertEqual(frame(.centerHalf), CGRect(x: 860, y: 30, width: 1720, height: 1352))
    }

    /**
     * @brief  Comprueba los cuartos.
     */
    func testQuarters() {
        XCTAssertEqual(frame(.topLeft), CGRect(x: 0, y: 30, width: 1720, height: 676))
        XCTAssertEqual(frame(.bottomRight), CGRect(x: 1720, y: 706, width: 1720, height: 676))
    }

    /**
     * @brief  Comprueba que los tercios cubren la pantalla sin huecos.
     */
    func testThirdsCoverWithoutGaps() throws {
        let first = try XCTUnwrap(frame(.firstThird))
        let center = try XCTUnwrap(frame(.centerThird))
        let last = try XCTUnwrap(frame(.lastThird))
        XCTAssertEqual(first.minX, visible.minX)
        XCTAssertLessThanOrEqual(center.minX, first.maxX)
        XCTAssertLessThanOrEqual(last.minX, center.maxX)
        XCTAssertEqual(last.maxX, visible.maxX)
        XCTAssertEqual(try XCTUnwrap(frame(.firstTwoThirds)).maxX, center.maxX)
    }

    /**
     * @brief  Comprueba los tercios de media altura: rejilla de 3 × 2 sin huecos.
     */
    func testSixths() throws {
        XCTAssertEqual(frame(.topLeftSixth), CGRect(x: 0, y: 30, width: 1147, height: 676))
        XCTAssertEqual(frame(.bottomRightSixth), CGRect(x: 2293, y: 706, width: 1147, height: 676))
        let top = try [WindowAction.topLeftSixth, .topCenterSixth, .topRightSixth].map { try XCTUnwrap(frame($0)) }
        let bottom = try [WindowAction.bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth].map { try XCTUnwrap(frame($0)) }
        for row in [top, bottom] {
            XCTAssertEqual(row[0].minX, visible.minX)
            XCTAssertLessThanOrEqual(row[1].minX, row[0].maxX)
            XCTAssertLessThanOrEqual(row[2].minX, row[1].maxX)
            XCTAssertEqual(row[2].maxX, visible.maxX)
        }
        XCTAssertLessThanOrEqual(bottom[0].minY, top[0].maxY)
        XCTAssertEqual(bottom[0].maxY, visible.maxY)
        XCTAssertEqual(WindowAction.topRightSixth.defaultShortcut?.display, "⌃⌥⇧O")
    }

    /**
     * @brief  Comprueba maximizar, casi maximizar y maximizar altura.
     */
    func testMaximizeVariants() throws {
        XCTAssertEqual(frame(.maximize), visible)
        let almost = try XCTUnwrap(frame(.almostMaximize))
        XCTAssertEqual(almost.midX, visible.midX, accuracy: 1)
        XCTAssertEqual(almost.width, visible.width * 0.9, accuracy: 1)
        XCTAssertEqual(frame(.maximizeHeight), CGRect(x: 506, y: 30, width: 920, height: 1352))
    }

    /**
     * @brief  Comprueba que centrar conserva el tamaño y lo limita a la pantalla.
     */
    func testCenterKeepsSizeAndClamps() throws {
        XCTAssertEqual(frame(.center), CGRect(x: 1260, y: 394, width: 920, height: 624))
        let huge = CGRect(x: 0, y: 0, width: 5000, height: 3000)
        let clamped = try XCTUnwrap(LayoutEngine.frame(for: .center, window: huge, visible: visible))
        XCTAssertEqual(clamped, visible)
    }

    /**
     * @brief  Comprueba que restaurar no se calcula aquí (depende del historial).
     */
    func testRestoreIsNil() {
        XCTAssertNil(frame(.restore))
    }

    /**
     * @brief  Comprueba la tolerancia al comparar marcos.
     */
    func testMatchesTolerance() {
        let a = CGRect(x: 0, y: 30, width: 1720, height: 1352)
        XCTAssertTrue(LayoutEngine.matches(a, a.offsetBy(dx: 1, dy: -1)))
        XCTAssertFalse(LayoutEngine.matches(a, a.offsetBy(dx: 40, dy: 0)))
    }

    /**
     * @brief  Comprueba que todas las acciones con atajo tienen uno distinto.
     */
    func testDefaultShortcutsAreUnique() {
        let shortcuts = WindowAction.allCases.compactMap(\.defaultShortcut)
        XCTAssertEqual(shortcuts.count, Set(shortcuts).count)
        XCTAssertEqual(WindowAction.leftHalf.defaultShortcut?.display, "⌃⌥←")
        XCTAssertEqual(Shortcut.Modifiers([.control, .option]).carbonFlags, 0x1800)
    }
}
