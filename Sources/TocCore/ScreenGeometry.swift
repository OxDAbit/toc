/*
-------------------------------------------------------------------------------
Name:     Sources/TocCore/ScreenGeometry.swift
Purpose:  Conversión entre las coordenadas de Cocoa (origen abajo a la
          izquierda) y las de Accesibilidad/WindowServer (origen arriba a la
          izquierda), elección de la pantalla en la que está una ventana y
          traslado proporcional de una ventana a otra pantalla.
Version:  v0.0.2
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import CoreGraphics

/// Sentido en el que se recorren las pantallas.
public enum ScreenDirection: Sendable {
    case next, previous
}

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

    /**
     * @brief  Devuelve la pantalla vecina en el orden de izquierda a derecha.
     *
     * Las pantallas se ordenan por su borde izquierdo (y, si empatan, por el
     * superior). Al llegar al final se vuelve a empezar.
     *
     * @param[in]  index      Índice de la pantalla actual en screens.
     * @param[in]  screens    Marcos completos de las pantallas.
     * @param[in]  direction  Siguiente o anterior.
     * @return Índice de la pantalla vecina, o nil si solo hay una pantalla.
     */
    public static func adjacentIndex(from index: Int, screens: [CGRect], direction: ScreenDirection) -> Int? {
        guard screens.count > 1, screens.indices.contains(index) else { return nil }
        let order = screens.indices.sorted {
            (screens[$0].minX, screens[$0].minY) < (screens[$1].minX, screens[$1].minY)
        }
        guard let position = order.firstIndex(of: index) else { return nil }
        let step = direction == .next ? 1 : order.count - 1
        return order[(position + step) % order.count]
    }

    /**
     * @brief  Lleva una ventana a otra pantalla conservando su posición y tamaño relativos.
     *
     * Si la ventana ocupaba la mitad izquierda de su pantalla, ocupará la mitad
     * izquierda de la nueva. El resultado se limita a la zona útil de destino.
     *
     * @param[in]  window       Marco actual de la ventana.
     * @param[in]  source       Zona útil de la pantalla de origen.
     * @param[in]  destination  Zona útil de la pantalla de destino.
     * @return Marco en la pantalla de destino, redondeado a puntos enteros.
     */
    public static func transfer(_ window: CGRect, from source: CGRect, to destination: CGRect) -> CGRect {
        guard source.width > 0, source.height > 0 else { return window }
        let width = min(window.width / source.width * destination.width, destination.width)
        let height = min(window.height / source.height * destination.height, destination.height)
        var x = destination.minX + (window.minX - source.minX) / source.width * destination.width
        var y = destination.minY + (window.minY - source.minY) / source.height * destination.height
        x = min(max(x, destination.minX), destination.maxX - width)
        y = min(max(y, destination.minY), destination.maxY - height)
        return LayoutEngine.rounded(CGRect(x: x, y: y, width: width, height: height))
    }
}
