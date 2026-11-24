/*
-------------------------------------------------------------------------------
Name:     Sources/TocCore/LayoutEngine.swift
Purpose:  Cálculo puro del marco de destino de cada acción. Trabaja en el
          sistema de coordenadas de Accesibilidad y WindowServer (origen
          arriba a la izquierda de la pantalla principal, eje Y hacia abajo).
Version:  v0.0.2
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import CoreGraphics

public enum LayoutEngine {

    /// Fracción de la zona útil que ocupa «Casi maximizar».
    public static let almostMaximizeRatio: CGFloat = 0.9

    /**
     * @brief  Calcula el marco de destino de una acción.
     *
     * @param[in]  action   Acción solicitada.
     * @param[in]  window   Marco actual de la ventana.
     * @param[in]  visible  Zona útil de la pantalla (sin barra de menús ni Dock).
     * @return Marco de destino redondeado a puntos enteros, o nil para .restore
     *         (depende del historial) y para las acciones de pantalla (dependen
     *         de las demás pantallas; ver ScreenGeometry.transfer).
     */
    public static func frame(for action: WindowAction, window: CGRect, visible: CGRect) -> CGRect? {
        let v = visible
        let halfW = v.width / 2, halfH = v.height / 2
        let thirdW = v.width / 3
        let rect: CGRect
        switch action {
        case .leftHalf: rect = CGRect(x: v.minX, y: v.minY, width: halfW, height: v.height)
        case .rightHalf: rect = CGRect(x: v.minX + halfW, y: v.minY, width: halfW, height: v.height)
        case .centerHalf: rect = CGRect(x: v.minX + v.width / 4, y: v.minY, width: halfW, height: v.height)
        case .topHalf: rect = CGRect(x: v.minX, y: v.minY, width: v.width, height: halfH)
        case .bottomHalf: rect = CGRect(x: v.minX, y: v.minY + halfH, width: v.width, height: halfH)
        case .topLeft: rect = CGRect(x: v.minX, y: v.minY, width: halfW, height: halfH)
        case .topRight: rect = CGRect(x: v.minX + halfW, y: v.minY, width: halfW, height: halfH)
        case .bottomLeft: rect = CGRect(x: v.minX, y: v.minY + halfH, width: halfW, height: halfH)
        case .bottomRight: rect = CGRect(x: v.minX + halfW, y: v.minY + halfH, width: halfW, height: halfH)
        case .firstThird: rect = CGRect(x: v.minX, y: v.minY, width: thirdW, height: v.height)
        case .centerThird: rect = CGRect(x: v.minX + thirdW, y: v.minY, width: thirdW, height: v.height)
        case .lastThird: rect = CGRect(x: v.minX + 2 * thirdW, y: v.minY, width: thirdW, height: v.height)
        case .firstTwoThirds: rect = CGRect(x: v.minX, y: v.minY, width: 2 * thirdW, height: v.height)
        case .centerTwoThirds: rect = CGRect(x: v.minX + thirdW / 2, y: v.minY, width: 2 * thirdW, height: v.height)
        case .lastTwoThirds: rect = CGRect(x: v.minX + thirdW, y: v.minY, width: 2 * thirdW, height: v.height)
        case .topLeftSixth: rect = CGRect(x: v.minX, y: v.minY, width: thirdW, height: halfH)
        case .topCenterSixth: rect = CGRect(x: v.minX + thirdW, y: v.minY, width: thirdW, height: halfH)
        case .topRightSixth: rect = CGRect(x: v.minX + 2 * thirdW, y: v.minY, width: thirdW, height: halfH)
        case .bottomLeftSixth: rect = CGRect(x: v.minX, y: v.minY + halfH, width: thirdW, height: halfH)
        case .bottomCenterSixth: rect = CGRect(x: v.minX + thirdW, y: v.minY + halfH, width: thirdW, height: halfH)
        case .bottomRightSixth: rect = CGRect(x: v.minX + 2 * thirdW, y: v.minY + halfH, width: thirdW, height: halfH)
        case .maximize: rect = v
        case .almostMaximize:
            let w = v.width * almostMaximizeRatio, h = v.height * almostMaximizeRatio
            rect = CGRect(x: v.midX - w / 2, y: v.midY - h / 2, width: w, height: h)
        case .maximizeHeight: rect = CGRect(x: window.minX, y: v.minY, width: window.width, height: v.height)
        case .center:
            let w = min(window.width, v.width), h = min(window.height, v.height)
            rect = CGRect(x: v.midX - w / 2, y: v.midY - h / 2, width: w, height: h)
        case .restore, .nextDisplay, .previousDisplay:
            return nil
        }
        return rounded(rect)
    }

    /**
     * @brief  Redondea un marco a puntos enteros sin perder cobertura.
     *
     * El origen se redondea hacia abajo y el borde opuesto hacia arriba, para
     * que dos mitades contiguas no dejen hueco entre ellas.
     *
     * @param[in]  rect  Marco a redondear.
     * @return Marco con coordenadas enteras.
     */
    public static func rounded(_ rect: CGRect) -> CGRect {
        let minX = rect.minX.rounded(.down), minY = rect.minY.rounded(.down)
        let maxX = rect.maxX.rounded(.up), maxY = rect.maxY.rounded(.up)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /**
     * @brief  Indica si dos marcos coinciden dentro de una tolerancia.
     *
     * Algunas apps ajustan el tamaño pedido (por ejemplo, los terminales lo
     * redondean a la rejilla de caracteres), así que se admite un margen.
     *
     * @param[in]  a          Primer marco.
     * @param[in]  b          Segundo marco.
     * @param[in]  tolerance  Diferencia máxima admitida en cada borde, en puntos.
     * @return true si los cuatro bordes están dentro de la tolerancia.
     */
    public static func matches(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
            && abs(a.maxX - b.maxX) <= tolerance && abs(a.maxY - b.maxY) <= tolerance
    }
}
