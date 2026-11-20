/*
-------------------------------------------------------------------------------
Name:     Sources/toc/main.swift
Purpose:  Punto de entrada de toc: arranca la app como accesorio de la barra
          de menús (sin icono en el Dock).
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
