/*
-------------------------------------------------------------------------------
Name:     scripts/make-icon.swift
Purpose:  Genera el logo de toc (monograma: la «o» convertida en una ventana
          con su mitad rellena) a partir de una única geometría:
            - assets/logo.svg       logo a color
            - assets/logo-mono.svg  versión de una tinta (barra de menús)
            - assets/icon.png       icono de 512 px para el README
            - Resources/toc.icns    icono de la app
          Uso: swift scripts/make-icon.swift (desde la raíz del repositorio).
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit
import Foundation

/// Geometría del logo en un lienzo de 512 × 512 (origen arriba a la izquierda).
enum Logo {
    static let canvas: CGFloat = 512
    /// Cuerpo del icono, en la retícula de iconos de macOS (824/1024).
    static let body = CGRect(x: 50, y: 50, width: 412, height: 412)
    static let bodyRadius: CGFloat = 92
    /// Ventana interior (la «o»).
    static let window = CGRect(x: 158, y: 158, width: 196, height: 196)
    static let windowRadius: CGFloat = 50
    static let stroke: CGFloat = 28

    static let petrolTop = "#2b6070"
    static let petrol = "#1e4a57"
    static let paper = "#efebe4"
    static let vanilla = "#f3e5ab"
}

/**
 * @brief  Devuelve el trazado de la mitad izquierda de la ventana, en SVG.
 *
 * @param[in]  w  Rectángulo de la ventana.
 * @param[in]  r  Radio de las esquinas.
 * @return Atributo «d» del trazado.
 */
func halfPath(_ w: CGRect, _ r: CGFloat) -> String {
    let midX = w.midX
    return "M\(w.minX) \(w.minY + r)a\(r) \(r) 0 0 1 \(r)-\(r)h\(midX - w.minX - r)v\(w.height)"
        + "h-\(midX - w.minX - r)a\(r) \(r) 0 0 1-\(r)-\(r)z"
}

/**
 * @brief  Compone el SVG del logo a color.
 *
 * @return Documento SVG.
 */
func colorSVG() -> String {
    let b = Logo.body, w = Logo.window
    return """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-label="toc">
      <defs><linearGradient id="toc-g" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="\(Logo.petrolTop)"/><stop offset="1" stop-color="\(Logo.petrol)"/>
      </linearGradient></defs>
      <rect x="\(b.minX)" y="\(b.minY)" width="\(b.width)" height="\(b.height)" rx="\(Logo.bodyRadius)" fill="url(#toc-g)"/>
      <path d="\(halfPath(w, Logo.windowRadius))" fill="\(Logo.vanilla)"/>
      <rect x="\(w.minX)" y="\(w.minY)" width="\(w.width)" height="\(w.height)" rx="\(Logo.windowRadius)" fill="none" stroke="\(Logo.paper)" stroke-width="\(Logo.stroke)"/>
    </svg>

    """
}

/**
 * @brief  Compone el SVG de una tinta (solo la ventana, sin el cuerpo).
 *
 * @return Documento SVG que usa currentColor.
 */
func monoSVG() -> String {
    let w = CGRect(x: 96, y: 96, width: 320, height: 320)
    return """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-label="toc">
      <rect x="\(w.minX)" y="\(w.minY)" width="\(w.width)" height="\(w.height)" rx="80" fill="none" stroke="currentColor" stroke-width="44"/>
      <path d="\(halfPath(w, 80))" fill="currentColor"/>
    </svg>

    """
}

/**
 * @brief  Convierte un color hexadecimal en CGColor.
 *
 * @param[in]  hex  Color en formato #rrggbb.
 * @return Color en sRGB.
 */
func color(_ hex: String) -> CGColor {
    let value = Int(hex.dropFirst(), radix: 16) ?? 0
    return CGColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                   blue: CGFloat(value & 0xFF) / 255, alpha: 1)
}

/**
 * @brief  Dibuja el logo a color en un PNG cuadrado.
 *
 * @param[in]  pixels  Lado de la imagen en píxeles.
 * @param[in]  url     Archivo de destino.
 */
func writePNG(pixels: Int, to url: URL) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                              space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw NSError(domain: "toc", code: 1)
    }
    let scale = CGFloat(pixels) / Logo.canvas
    // Pasa a coordenadas con origen arriba a la izquierda, como el SVG.
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: scale, y: -scale)

    let body = CGPath(roundedRect: Logo.body, cornerWidth: Logo.bodyRadius, cornerHeight: Logo.bodyRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: space, colors: [color(Logo.petrolTop), color(Logo.petrol)] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: Logo.body.minY),
                           end: CGPoint(x: 0, y: Logo.body.maxY), options: [])
    ctx.restoreGState()

    let w = Logo.window, r = Logo.windowRadius

    let half = CGMutablePath()
    half.move(to: CGPoint(x: w.midX, y: w.minY))
    half.addLine(to: CGPoint(x: w.minX + r, y: w.minY))
    half.addArc(tangent1End: CGPoint(x: w.minX, y: w.minY), tangent2End: CGPoint(x: w.minX, y: w.minY + r), radius: r)
    half.addLine(to: CGPoint(x: w.minX, y: w.maxY - r))
    half.addArc(tangent1End: CGPoint(x: w.minX, y: w.maxY), tangent2End: CGPoint(x: w.minX + r, y: w.maxY), radius: r)
    half.addLine(to: CGPoint(x: w.midX, y: w.maxY))
    half.closeSubpath()
    ctx.addPath(half)
    ctx.setFillColor(color(Logo.vanilla))
    ctx.fillPath()

    // El marco va encima del relleno, para que tenga el mismo grosor en todo el contorno.
    ctx.addPath(CGPath(roundedRect: w, cornerWidth: r, cornerHeight: r, transform: nil))
    ctx.setStrokeColor(color(Logo.paper))
    ctx.setLineWidth(Logo.stroke)
    ctx.strokePath()

    guard let image = ctx.makeImage(),
          let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw NSError(domain: "toc", code: 2)
    }
    try data.write(to: url)
}

/**
 * @brief  Genera el .icns con todos los tamaños que pide macOS.
 *
 * @param[in]  url  Archivo .icns de destino.
 */
func writeICNS(to url: URL) throws {
    let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("toc.iconset")
    try? FileManager.default.removeItem(at: iconset)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    for base in [16, 32, 128, 256, 512] {
        try writePNG(pixels: base, to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
        try writePNG(pixels: base * 2, to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconset.path, "-o", url.path]
    try process.run()
    process.waitUntilExit()
    try? FileManager.default.removeItem(at: iconset)
    guard process.terminationStatus == 0 else { throw NSError(domain: "toc", code: 3) }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("assets")
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
try colorSVG().write(to: assets.appendingPathComponent("logo.svg"), atomically: true, encoding: .utf8)
try monoSVG().write(to: assets.appendingPathComponent("logo-mono.svg"), atomically: true, encoding: .utf8)
try writePNG(pixels: 512, to: assets.appendingPathComponent("icon.png"))
try writeICNS(to: root.appendingPathComponent("Resources/toc.icns"))
print("✓ assets/logo.svg, assets/logo-mono.svg, assets/icon.png y Resources/toc.icns generados")
