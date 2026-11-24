/*
-------------------------------------------------------------------------------
Name:     Sources/toc/MenuIcon.swift
Purpose:  Iconos del menú dibujados por código: una pantalla en miniatura con
          la zona de destino de cada acción rellena en azul. La zona sale del
          propio LayoutEngine, así que el icono siempre coincide con lo que
          hace la acción. También genera una hoja de muestra en PNG.
Version:  v0.0.2
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit
import TocCore

@MainActor
enum MenuIcon {

    /// Tamaño del icono en el menú, en puntos.
    static let size = NSSize(width: 22, height: 16)

    /// Azul de la app: azul cianotipo de 0xDA bit (#1C3F6E) en modo claro y
    /// una versión más luminosa en modo oscuro, para que contraste.
    static let accent = NSColor(name: "tocAccent") { appearance in
        if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            return NSColor(srgbRed: 0x6F / 255, green: 0x9B / 255, blue: 0xD8 / 255, alpha: 1)
        }
        return NSColor(srgbRed: 0x1C / 255, green: 0x3F / 255, blue: 0x6E / 255, alpha: 1)
    }

    /// Lienzo de referencia para calcular la zona con LayoutEngine (proporción 4:3).
    private static let canvas = CGRect(x: 0, y: 0, width: 120, height: 90)
    /// Ventana de referencia para las acciones que dependen de la ventana (centrar, altura).
    private static let sampleWindow = CGRect(x: 30, y: 22, width: 60, height: 46)

    /**
     * @brief  Crea el icono de una acción.
     *
     * El dibujo se hace al pintar, así que los colores siguen el modo claro u
     * oscuro del menú.
     *
     * @param[in]  action  Acción representada.
     * @return Imagen del icono.
     */
    static func image(for action: WindowAction) -> NSImage {
        let image = NSImage(size: size, flipped: true) { rect in
            draw(action, in: rect)
            return true
        }
        image.accessibilityDescription = action.title
        return image
    }

    /**
     * @brief  Dibuja el icono de una acción en un rectángulo.
     *
     * @param[in]  action  Acción representada.
     * @param[in]  rect    Rectángulo de dibujo (contexto con el eje Y hacia abajo).
     */
    private static func draw(_ action: WindowAction, in rect: CGRect) {
        let screen = rect.insetBy(dx: 1, dy: 1.5)
        let outline = NSBezierPath(roundedRect: screen, xRadius: 2.5, yRadius: 2.5)

        // Fondo de la pantalla, para que se vea qué parte queda libre.
        NSGraphicsContext.saveGraphicsState()
        outline.addClip()
        NSColor.tertiaryLabelColor.withAlphaComponent(0.18).setFill()
        screen.fill()

        if let symbol = symbolName(for: action) {
            NSGraphicsContext.restoreGraphicsState()
            drawSymbol(symbol, in: screen)
        } else if let target = LayoutEngine.frame(for: action, window: sampleWindow, visible: canvas) {
            var zone = CGRect(x: screen.minX + target.minX / canvas.width * screen.width,
                              y: screen.minY + target.minY / canvas.height * screen.height,
                              width: target.width / canvas.width * screen.width,
                              height: target.height / canvas.height * screen.height)
            // A este tamaño, el 90 % de «Casi maximizar» no se distingue de
            // «Maximizar»: se exagera el margen solo en el icono.
            if action == .almostMaximize { zone = screen.insetBy(dx: 2.5, dy: 2.5) }
            accent.setFill()
            zone.fill()
            NSGraphicsContext.restoreGraphicsState()
        } else {
            NSGraphicsContext.restoreGraphicsState()
        }

        outline.lineWidth = 1.2
        NSColor.secondaryLabelColor.setStroke()
        outline.stroke()
    }

    /**
     * @brief  Devuelve el símbolo de las acciones que no se dibujan como una zona.
     *
     * @param[in]  action  Acción representada.
     * @return Nombre del símbolo SF, o nil si la acción se dibuja como zona.
     */
    private static func symbolName(for action: WindowAction) -> String? {
        switch action {
        case .restore: "arrow.uturn.backward"
        case .nextDisplay: "arrow.right"
        case .previousDisplay: "arrow.left"
        default: nil
        }
    }

    /**
     * @brief  Dibuja un símbolo SF en azul en el centro del icono.
     *
     * @param[in]  name  Nombre del símbolo.
     * @param[in]  rect  Zona interior del icono.
     */
    private static func drawSymbol(_ name: String, in rect: CGRect) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 8, weight: .bold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [accent]))
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return }
        let symbolSize = symbol.size
        let origin = CGPoint(x: rect.midX - symbolSize.width / 2, y: rect.midY - symbolSize.height / 2)
        symbol.draw(in: CGRect(origin: origin, size: symbolSize), from: .zero, operation: .sourceOver,
                    fraction: 1, respectFlipped: true, hints: nil)
    }

    /**
     * @brief  Crea el logo de toc para la barra de menús, en versión de una tinta.
     *
     * Es el monograma de assets/logo-mono.svg: una ventana redondeada con la
     * mitad izquierda rellena. Se marca como plantilla para que macOS lo
     * pinte en blanco o negro según la barra de menús.
     *
     * @return Imagen de 18 × 18 puntos.
     */
    static func statusLogo() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            let frame = rect.insetBy(dx: 2.6, dy: 2.6)
            let radius: CGFloat = 3.6
            let outline = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
            NSColor.black.set()
            NSGraphicsContext.saveGraphicsState()
            outline.addClip()
            CGRect(x: frame.minX, y: frame.minY, width: frame.width / 2, height: frame.height).fill()
            NSGraphicsContext.restoreGraphicsState()
            outline.lineWidth = 2
            outline.stroke()
            return true
        }
        image.accessibilityDescription = "toc"
        return image
    }

    /**
     * @brief  Genera hojas de muestra (modo claro y oscuro) con todos los iconos.
     *
     * Se usa con «toc --render-icons <carpeta>» para revisar los iconos sin
     * abrir el menú.
     *
     * @param[in]  folder  Carpeta en la que se guardan los PNG.
     * @return Rutas de los archivos generados.
     */
    static func renderSheets(to folder: URL) throws -> [URL] {
        let scale: CGFloat = 3
        let rowHeight: CGFloat = 24, width: CGFloat = 260
        let actions = WindowAction.allCases
        let height = rowHeight * CGFloat(actions.count) + 16
        var written: [URL] = []

        for (name, appearanceName) in [("claro", NSAppearance.Name.aqua), ("oscuro", .darkAqua)] {
            guard let appearance = NSAppearance(named: appearanceName),
                  let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                                pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
                continue
            }
            bitmap.size = NSSize(width: width, height: height)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            appearance.performAsCurrentDrawingAppearance {
                NSColor.windowBackgroundColor.setFill()
                CGRect(x: 0, y: 0, width: width, height: height).fill()
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.menuFont(ofSize: 13),
                    .foregroundColor: NSColor.labelColor
                ]
                for (index, action) in actions.enumerated() {
                    let y = height - 8 - rowHeight * CGFloat(index + 1)
                    image(for: action).draw(in: CGRect(x: 12, y: y + 4.5, width: size.width, height: size.height))
                    (action.title as NSString).draw(at: CGPoint(x: 42, y: y + 4), withAttributes: attributes)
                }
            }
            NSGraphicsContext.restoreGraphicsState()
            let url = folder.appendingPathComponent("toc-iconos-\(name).png")
            try bitmap.representation(using: .png, properties: [:])?.write(to: url)
            written.append(url)
        }
        return written
    }
}
