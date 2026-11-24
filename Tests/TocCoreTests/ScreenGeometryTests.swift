/*
-------------------------------------------------------------------------------
Name:     Tests/TocCoreTests/ScreenGeometryTests.swift
Purpose:  Tests de la conversión de coordenadas, la elección de pantalla y
          el traslado de ventanas entre pantallas.
Version:  v0.0.2
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

    /**
     * @brief  Comprueba el orden de izquierda a derecha y la vuelta al principio.
     */
    func testAdjacentScreens() {
        // La principal (índice 0) está a la derecha de la secundaria (índice 1).
        let screens = [CGRect(x: 0, y: 0, width: 3440, height: 1440),
                       CGRect(x: -1920, y: 200, width: 1920, height: 1080)]
        XCTAssertEqual(ScreenGeometry.adjacentIndex(from: 0, screens: screens, direction: .next), 1)
        XCTAssertEqual(ScreenGeometry.adjacentIndex(from: 1, screens: screens, direction: .next), 0)
        XCTAssertEqual(ScreenGeometry.adjacentIndex(from: 0, screens: screens, direction: .previous), 1)
        XCTAssertNil(ScreenGeometry.adjacentIndex(from: 0, screens: [screens[0]], direction: .next))
    }

    /**
     * @brief  La mitad izquierda de una pantalla pasa a ser la mitad izquierda de la otra.
     */
    func testTransferKeepsRelativeLayout() {
        let source = CGRect(x: 0, y: 30, width: 3440, height: 1352)
        let destination = CGRect(x: 3440, y: 25, width: 1920, height: 1055)
        let leftHalf = CGRect(x: 0, y: 30, width: 1720, height: 1352)
        XCTAssertEqual(ScreenGeometry.transfer(leftHalf, from: source, to: destination),
                       CGRect(x: 3440, y: 25, width: 960, height: 1055))
    }

    /**
     * @brief  Una ventana que se sale de su pantalla queda dentro de la de destino.
     */
    func testTransferClampsInsideDestination() {
        let source = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let destination = CGRect(x: 1000, y: 0, width: 500, height: 500)
        let window = CGRect(x: 900, y: 900, width: 400, height: 400)
        let moved = ScreenGeometry.transfer(window, from: source, to: destination)
        XCTAssertTrue(destination.contains(moved))
    }
}
