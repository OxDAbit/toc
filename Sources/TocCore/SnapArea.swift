/*
-------------------------------------------------------------------------------
Name:     Sources/TocCore/SnapArea.swift
Purpose:  Zonas de ajuste al arrastrar una ventana: decide qué acción aplicar
          según dónde está el cursor respecto a los bordes y las esquinas de
          la pantalla. Coordenadas de Accesibilidad (origen arriba a la
          izquierda). Lógica pura, sin AppKit.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import CoreGraphics

public enum SnapArea {

    /// Distancia al borde, en puntos, a partir de la cual se activa una zona.
    public static let edgeMargin: CGFloat = 5
    /// Tamaño de las esquinas, en puntos, medido a lo largo de cada borde.
    public static let cornerSize: CGFloat = 40

    /**
     * @brief  Devuelve la acción que corresponde a la posición del cursor.
     *
     * - Esquinas: cuartos.
     * - Borde superior: maximizar.
     * - Bordes izquierdo y derecho: mitades.
     * - Borde inferior (fuera de las esquinas): ninguna.
     *
     * @param[in]  point   Posición del cursor.
     * @param[in]  screen  Marco completo de la pantalla en la que está el cursor.
     * @return Acción a aplicar al soltar, o nil si el cursor no está en ninguna zona.
     */
    public static func action(at point: CGPoint, screen: CGRect) -> WindowAction? {
        guard screen.insetBy(dx: -1, dy: -1).contains(point) else { return nil }

        // El cursor llega como mucho a maxX - 1 y maxY - 1.
        let left = point.x <= screen.minX + edgeMargin
        let right = point.x >= screen.maxX - 1 - edgeMargin
        let top = point.y <= screen.minY + edgeMargin
        let bottom = point.y >= screen.maxY - 1 - edgeMargin

        let nearLeft = point.x <= screen.minX + cornerSize
        let nearRight = point.x >= screen.maxX - 1 - cornerSize
        let nearTop = point.y <= screen.minY + cornerSize
        let nearBottom = point.y >= screen.maxY - 1 - cornerSize

        if (left && nearTop) || (top && nearLeft) { return .topLeft }
        if (right && nearTop) || (top && nearRight) { return .topRight }
        if (left && nearBottom) || (bottom && nearLeft) { return .bottomLeft }
        if (right && nearBottom) || (bottom && nearRight) { return .bottomRight }
        if top { return .maximize }
        if left { return .leftHalf }
        if right { return .rightHalf }
        return nil
    }
}
