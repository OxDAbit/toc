/*
-------------------------------------------------------------------------------
Name:     Sources/TocCore/AXHealth.swift
Purpose:  Detector del fallo de Accesibilidad tras el reposo diagnosticado con
          toc-probe: WindowServer ve ventanas, pero la lista de ventanas de AX
          devuelve elementos con rol AXApplication. Lógica pura, sin AppKit.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

/// Estado de la API de Accesibilidad.
public enum AXHealth: Equatable, Sendable {
    /// AX devuelve ventanas reales.
    case healthy
    /// AX devuelve la propia app en lugar de sus ventanas (fallo de macOS).
    case broken
    /// toc no tiene permiso de Accesibilidad.
    case permissionMissing
    /// No hay datos suficientes para decidir.
    case unknown

    /// Prioridad al combinar observaciones de varias apps (mayor gana).
    var severity: Int {
        switch self {
        case .unknown: 0
        case .healthy: 1
        case .broken: 2
        case .permissionMissing: 3
        }
    }
}

/// Lo que se observa de una app al pedir sus ventanas.
public struct AXObservation: Sendable {
    /// Ventanas normales (capa 0) que WindowServer ve para la app.
    public let windowServerWindows: Int
    /// Código AXError de la llamada que pide la lista de ventanas.
    public let error: Int32
    /// Roles de los elementos devueltos (vacío si la llamada falló).
    public let roles: [String]

    /**
     * @brief  Crea una observación.
     *
     * @param[in]  windowServerWindows  Ventanas de capa 0 según WindowServer.
     * @param[in]  error                Código AXError (0 = éxito).
     * @param[in]  roles                Roles de los elementos devueltos.
     */
    public init(windowServerWindows: Int, error: Int32, roles: [String]) {
        self.windowServerWindows = windowServerWindows
        self.error = error
        self.roles = roles
    }
}

public enum AXHealthDetector {

    /// kAXErrorAPIDisabled: el proceso no tiene permiso de Accesibilidad.
    public static let apiDisabled: Int32 = -25211

    /**
     * @brief  Decide el estado de Accesibilidad a partir de una app.
     *
     * @param[in]  observation  Lo observado en la app.
     * @return Estado deducido.
     */
    public static func evaluate(_ observation: AXObservation) -> AXHealth {
        if observation.error == apiDisabled { return .permissionMissing }
        guard observation.windowServerWindows > 0, observation.error == 0 else { return .unknown }
        if observation.roles.contains("AXApplication") { return .broken }
        if observation.roles.contains("AXWindow") { return .healthy }
        return .unknown
    }

    /**
     * @brief  Combina observaciones de varias apps en un único estado.
     *
     * Basta una app con el árbol corrupto para declarar el fallo: en el estado
     * normal ninguna app devuelve AXApplication en su lista de ventanas.
     *
     * @param[in]  observations  Observaciones de varias apps.
     * @return Estado más grave observado.
     */
    public static func evaluate(_ observations: [AXObservation]) -> AXHealth {
        observations.map(evaluate).max { $0.severity < $1.severity } ?? .unknown
    }
}
