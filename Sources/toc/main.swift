/*
-------------------------------------------------------------------------------
Name:     Sources/toc/main.swift
Purpose:  Punto de entrada de toc: arranca la app como accesorio de la barra
          de menús (sin icono en el Dock). Con «--render-icons <carpeta>»
          solo genera las hojas de muestra de los iconos y termina.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit

let arguments = CommandLine.arguments
if let index = arguments.firstIndex(of: "--render-icons"), index + 1 < arguments.count {
    let folder = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
    do {
        try MenuIcon.renderSheets(to: folder).forEach { print($0.path) }
        exit(0)
    } catch {
        print("No se pudieron generar los iconos: \(error)")
        exit(1)
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
