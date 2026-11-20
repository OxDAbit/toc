/*
-------------------------------------------------------------------------------
Name:     Tests/TocCoreTests/ScreenGeometryTests.swift
Purpose:  Tests de la conversión de coordenadas y de la elección de pantalla.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import CoreGraphics
import XCTest
@testable import TocCore

final class ScreenGeometryTests: XCTestCase {

    /**
     * @brief  Comprueba la conversión con los datos reales de la sonda.
     *
     * Cocoa: visible=(0, 58, 3440×1352) → AX: (0, 30, 3440×1352).
     */
    func testCocoaToTopLeft() {
        let cocoa = CGRect(x: 0, y: 58, width: 3440, height: 1352)
        let converted = ScreenGeometry.topLeft(fromCocoa: cocoa, primaryHeight: 1440)
        XCTAssertEqual(converted, CGRect(x: 0, y: 30, width: 3440, height: 1352))
    }

    /**
     * @brief  Comprueba que se elige la pantalla con más superficie de la ventana.
     */
    func testScreenWithLargestOverlap() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080),
                       CGRect(x: 1920, y: 0, width: 2560, height: 1440)]
        let window = CGRect(x: 1800, y: 100, width: 800, height: 600)
        XCTAssertEqual(ScreenGeometry.screenIndex(for: window, screens: screens), 1)
    }

    /**
     * @brief  Comprueba el caso de una ventana fuera de todas las pantallas.
     */
    func testWindowOffscreenPicksNearest() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080),
                       CGRect(x: 1920, y: 0, width: 2560, height: 1440)]
        let window = CGRect(x: 5000, y: 200, width: 100, height: 100)
        XCTAssertEqual(ScreenGeometry.screenIndex(for: window, screens: screens), 1)
        XCTAssertNil(ScreenGeometry.screenIndex(for: window, screens: []))
    }
}
