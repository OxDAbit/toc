/*
-------------------------------------------------------------------------------
Name:     Tests/TocCoreTests/SnapAreaTests.swift
Purpose:  Tests de las zonas de ajuste al arrastrar, con la pantalla real del
          C34H89x (3440×1440) y con una segunda pantalla desplazada.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import CoreGraphics
import XCTest
@testable import TocCore

final class SnapAreaTests: XCTestCase {

    let screen = CGRect(x: 0, y: 0, width: 3440, height: 1440)

    /**
     * @brief  Atajo para consultar la zona de un punto en la pantalla de prueba.
     *
     * @param[in]  x  Coordenada horizontal del cursor.
     * @param[in]  y  Coordenada vertical del cursor.
     * @return Acción de la zona, o nil.
     */
    func area(_ x: CGFloat, _ y: CGFloat) -> WindowAction? {
        SnapArea.action(at: CGPoint(x: x, y: y), screen: screen)
    }

    /**
     * @brief  Comprueba los bordes.
     */
    func testEdges() {
        XCTAssertEqual(area(0, 700), .leftHalf)
        XCTAssertEqual(area(3439, 700), .rightHalf)
        XCTAssertEqual(area(1720, 0), .maximize)
        XCTAssertNil(area(1720, 1439))
    }

    /**
     * @brief  Comprueba las esquinas, tanto por el borde vertical como por el horizontal.
     */
    func testCorners() {
        XCTAssertEqual(area(0, 10), .topLeft)
        XCTAssertEqual(area(10, 0), .topLeft)
        XCTAssertEqual(area(3439, 20), .topRight)
        XCTAssertEqual(area(0, 1430), .bottomLeft)
        XCTAssertEqual(area(3420, 1439), .bottomRight)
    }

    /**
     * @brief  Comprueba que el centro y los puntos fuera de la pantalla no activan nada.
     */
    func testNoArea() {
        XCTAssertNil(area(1720, 700))
        XCTAssertNil(area(4000, 700))
    }

    /**
     * @brief  Comprueba una pantalla secundaria a la derecha de la principal.
     */
    func testSecondaryScreen() {
        let second = CGRect(x: 3440, y: 0, width: 1920, height: 1080)
        XCTAssertEqual(SnapArea.action(at: CGPoint(x: 3440, y: 500), screen: second), .leftHalf)
        XCTAssertEqual(SnapArea.action(at: CGPoint(x: 5359, y: 500), screen: second), .rightHalf)
    }
}
