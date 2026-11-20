// swift-tools-version:6.2
/*
-------------------------------------------------------------------------------
Name:     tools/toc-probe/Package.swift
Purpose:  Manifiesto de Swift Package Manager de toc-probe, la sonda de
          diagnóstico de Accesibilidad que precede al desarrollo de toc.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import PackageDescription

let package = Package(
    name: "toc-probe",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "toc-probe",
            path: "Sources/toc-probe"
        )
    ]
)
