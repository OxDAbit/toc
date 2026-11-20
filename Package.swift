// swift-tools-version:6.2
/*
-------------------------------------------------------------------------------
Name:     Package.swift
Purpose:  Manifiesto de Swift Package Manager de toc. Define la librería
          TocCore (cálculos puros, con tests), el ejecutable toc (app de
          barra de menús) y sus tests. El empaquetado en toc.app lo hace
          scripts/build-app.sh.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import PackageDescription

let package = Package(
    name: "toc",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "toc", targets: ["toc"])
    ],
    targets: [
        .target(
            name: "TocCore",
            path: "Sources/TocCore"
        ),
        .executableTarget(
            name: "toc",
            dependencies: ["TocCore"],
            path: "Sources/toc"
        ),
        .testTarget(
            name: "TocCoreTests",
            dependencies: ["TocCore"],
            path: "Tests/TocCoreTests"
        )
    ]
)
