/*
-------------------------------------------------------------------------------
Name:     Tests/TocCoreTests/AXHealthTests.swift
Purpose:  Tests del detector del fallo de Accesibilidad con los casos reales
          capturados por toc-probe el 20/11/2026.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import XCTest
@testable import TocCore

final class AXHealthTests: XCTestCase {

    /**
     * @brief  Estado normal: Finder tras reiniciar (3 ventanas + escritorio).
     */
    func testHealthyFinder() {
        let observation = AXObservation(windowServerWindows: 3, error: 0,
                                        roles: ["AXWindow", "AXWindow", "AXWindow", "AXScrollArea"])
        XCTAssertEqual(AXHealthDetector.evaluate(observation), .healthy)
    }

    /**
     * @brief  Estado roto: Finder tras el reposo (la lista devuelve la propia app).
     */
    func testBrokenFinder() {
        let observation = AXObservation(windowServerWindows: 3, error: 0,
                                        roles: ["AXApplication", "AXApplication", "AXApplication", "AXScrollArea"])
        XCTAssertEqual(AXHealthDetector.evaluate(observation), .broken)
    }

    /**
     * @brief  Sin permiso de Accesibilidad.
     */
    func testPermissionMissing() {
        let observation = AXObservation(windowServerWindows: 3, error: -25211, roles: [])
        XCTAssertEqual(AXHealthDetector.evaluate(observation), .permissionMissing)
    }

    /**
     * @brief  Una app sin ventanas no permite decidir.
     */
    func testNoWindowsIsUnknown() {
        let observation = AXObservation(windowServerWindows: 0, error: 0, roles: [])
        XCTAssertEqual(AXHealthDetector.evaluate(observation), .unknown)
    }

    /**
     * @brief  Basta una app rota para declarar el fallo al combinar varias.
     */
    func testCombinedPrefersBroken() {
        let healthy = AXObservation(windowServerWindows: 1, error: 0, roles: ["AXWindow"])
        let broken = AXObservation(windowServerWindows: 1, error: 0, roles: ["AXApplication"])
        let empty = AXObservation(windowServerWindows: 0, error: 0, roles: [])
        XCTAssertEqual(AXHealthDetector.evaluate([healthy, empty, broken]), .broken)
        XCTAssertEqual(AXHealthDetector.evaluate([healthy, empty]), .healthy)
        XCTAssertEqual(AXHealthDetector.evaluate([]), .unknown)
    }
}
