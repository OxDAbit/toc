/*
-------------------------------------------------------------------------------
Name:     Sources/toc/Log.swift
Purpose:  Registros de toc en el log unificado de macOS (subsistema
          com.oxdabit.toc), consultables con «log show» o Consola.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import os

enum Log {
    static let subsystem = "com.oxdabit.toc"
    static let ax = Logger(subsystem: subsystem, category: "ax")
    static let mover = Logger(subsystem: subsystem, category: "mover")
    static let hotkeys = Logger(subsystem: subsystem, category: "hotkeys")
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}
