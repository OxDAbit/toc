/*
-------------------------------------------------------------------------------
Name:     Sources/TocCore/ScreenGeometry.swift
Purpose:  Conversión entre las coordenadas de Cocoa (origen abajo a la
          izquierda) y las de Accesibilidad/WindowServer (origen arriba a la
          izquierda), y elección de la pantalla en la que está una ventana.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import CoreGraphics

public enum ScreenGeometry {

    /**
     * @brief  Convierte un rectángulo de Cocoa a coordenadas de Accesibilidad.
     *
     * @param[in]  rect           Rectángulo en coordenadas de Cocoa.
     * @param[in]  primaryHeight  Altura de la pantalla principal (la del menú).
     * @return Rectángulo con origen arriba a la izquierda.
     */
    public static func topLeft(fromCocoa rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /**
     * @brief  Elige la pantalla en la que está la mayor parte de una ventana.
     *
     * @param[in]  window   Marco de la ventana (origen arriba a la izquierda).
     * @param[in]  screens  Marcos completos de las pantallas, en el mismo sistema.
     * @return Índice de la pantalla con más área en común; si no hay ninguna,
     *         la que contiene el centro más cercano; nil si no hay pantallas.
     */
    public static func screenIndex(for window: CGRect, screens: [CGRect]) -> Int? {
        guard !screens.isEmpty else { return nil }
        let areas = screens.map { screen -> CGFloat in
            let overlap = screen.intersection(window)
            return overlap.isNull ? 0 : overlap.width * overlap.height
        }
        if let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 {
            return best
        }
        let center = CGPoint(x: window.midX, y: window.midY)
        return screens.indices.min { a, b in
            distance(center, screens[a]) < distance(center, screens[b])
        }
    }

    /**
     * @brief  Distancia de un punto al centro de un rectángulo.
     *
     * @param[in]  point  Punto.
     * @param[in]  rect   Rectángulo.
     * @return Distancia euclídea.
     */
    static func distance(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
        let dx = point.x - rect.midX, dy = point.y - rect.midY
        return (dx * dx + dy * dy).squareRoot()
    }
}
