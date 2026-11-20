/*
-------------------------------------------------------------------------------
Name:     Sources/toc/FootprintWindow.swift
Purpose:  Vista previa semitransparente de dónde quedará la ventana al soltarla
          en una zona de ajuste. No recibe clics ni roba el foco.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit

@MainActor
final class FootprintWindow {

    private let panel: NSPanel
    private let box = NSView()

    /**
     * @brief  Crea el panel de la vista previa, oculto.
     */
    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        box.wantsLayer = true
        box.layer?.cornerRadius = 12
        box.layer?.borderWidth = 2
        panel.contentView = box
    }

    /**
     * @brief  Muestra la vista previa en un marco de Cocoa.
     *
     * @param[in]  frame  Marco en coordenadas de Cocoa (origen abajo a la izquierda).
     */
    func show(_ frame: CGRect) {
        let accent = NSColor.controlAccentColor
        box.layer?.backgroundColor = accent.withAlphaComponent(0.18).cgColor
        box.layer?.borderColor = accent.withAlphaComponent(0.7).cgColor
        panel.setFrame(frame.insetBy(dx: 4, dy: 4), display: true)
        panel.orderFrontRegardless()
    }

    /**
     * @brief  Oculta la vista previa.
     */
    func hide() {
        panel.orderOut(nil)
    }
}
