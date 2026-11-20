/*
-------------------------------------------------------------------------------
Name:     tools/toc-probe/Sources/toc-probe/main.swift
Purpose:  Punto de entrada de toc-probe. Recoge el estado del sistema, prueba
          la API de Accesibilidad contra las ventanas de una o varias apps,
          prueba vías alternativas (tokens remotos, hit-testing y Apple
          Events), opcionalmente mueve ventanas y las devuelve a su sitio, y
          emite un veredicto sobre dónde está el fallo.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit
import ApplicationServices

/// Opciones de la línea de órdenes.
struct Options {
    var move = false
    var all = false
    var deep = false
    var appleEvents = false
    var prompt = false
    var redact = false
    var help = false
    var bundleIDs: [String] = []
}

/// Ajustes globales del informe.
@MainActor
enum Report {
    /// Si se ocultan los títulos de las ventanas (pueden contener datos personales).
    static var redactTitles = false
}

/// Resultado de la prueba de movimiento de una ventana.
enum MoveOutcome {
    case moved
    case failed(String)
    case skipped(String)
}

/// Lo observado en una vía de acceso a las ventanas (AX estándar, tokens, hit-test…).
struct PathOutcome {
    let path: String
    var readable = false
    var move: MoveOutcome?
}

/// Resumen de lo observado en una app, usado para el veredicto final.
struct AppOutcome {
    let name: String
    let windowServerWindows: Int
    let fakeWindows: Int
    var paths: [PathOutcome]
    var appleEventsMoved: Bool?
}

/**
 * @brief  Interpreta los argumentos de la línea de órdenes.
 *
 * @param[in]  arguments  Argumentos recibidos, sin el nombre del ejecutable.
 * @return Opciones resultantes.
 */
func parse(_ arguments: [String]) -> Options {
    var options = Options()
    var iterator = arguments.makeIterator()
    while let argument = iterator.next() {
        switch argument {
        case "--move": options.move = true
        case "--all": options.all = true
        case "--deep": options.deep = true
        case "--applescript": options.appleEvents = true
        case "--prompt": options.prompt = true
        case "--redact": options.redact = true
        case "-h", "--help": options.help = true
        case "--app":
            if let id = iterator.next() { options.bundleIDs.append(id) }
        default:
            print("Argumento desconocido: \(argument)")
            options.help = true
        }
    }
    return options
}

/**
 * @brief  Muestra la ayuda de uso.
 */
func printHelp() {
    print("""
    toc-probe v0.0.1 — diagnóstico de Accesibilidad para gestores de ventanas

    Uso: toc-probe [--app <bundle-id>]... [--all] [--move] [--deep] [--applescript] [--redact] [--prompt]

      --app <id>     App que se inspecciona (por defecto: com.apple.finder).
      --all          Inspecciona todas las apps con ventanas.
      --move         Mueve 40 px una ventana de cada app y la devuelve a su sitio.
      --deep         Prueba vías alternativas a AX estándar: tokens remotos y hit-test.
      --applescript  Prueba a mover con Apple Events (solo apps scriptables;
                     macOS pedirá el permiso de Automatización).
      --redact       Oculta los títulos de las ventanas (para compartir el informe).
      --prompt      Pide a macOS el permiso de Accesibilidad si falta.

    Sin --move la sonda solo lee: no cambia nada.
    """)
}

/**
 * @brief  Imprime el título de una sección del informe.
 *
 * @param[in]  title  Texto del título.
 */
func section(_ title: String) {
    print("\n== \(title) " + String(repeating: "=", count: max(0, 70 - title.count)))
}

/**
 * @brief  Formatea una fecha en hora local, o un guion si no existe.
 *
 * @param[in]  date  Fecha a mostrar.
 * @return Fecha legible.
 */
func stamp(_ date: Date?) -> String {
    guard let date else { return "—" }
    let formatter = DateFormatter()
    formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
    return formatter.string(from: date)
}

/**
 * @brief  Espera procesando el run loop, para dar tiempo a que la ventana se mueva.
 *
 * @param[in]  seconds  Segundos de espera.
 */
@MainActor
func settle(_ seconds: TimeInterval) {
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
}

/**
 * @brief  Imprime el estado del sistema relevante para el diagnóstico.
 *
 * @param[in]  trusted  Si este proceso tiene permiso de Accesibilidad.
 */
@MainActor
func printSystem(trusted: Bool) {
    section("Sistema")
    print("macOS:            \(SystemInfo.osVersion()) · \(SystemInfo.machine())")
    print("Fecha:            \(stamp(Date()))")
    print("Arranque:         \(stamp(SystemInfo.kernelDate("kern.boottime")))")
    print("Último reposo:    \(stamp(SystemInfo.kernelDate("kern.sleeptime")))")
    print("Último despertar: \(stamp(SystemInfo.kernelDate("kern.waketime")))")

    section("Permiso de Accesibilidad")
    print("Concedido:        \(trusted ? "sí" : "NO")")
    print("App responsable:  \(SystemInfo.responsibleApp() ?? "desconocida")")

    section("Entrada Segura")
    let enabled = SystemInfo.secureInputEnabled()
    print("Activa:           \(enabled ? "sí" : "no")")
    if let pid = SystemInfo.secureInputPID() {
        let owner = SystemInfo.processName(pid) ?? "proceso inexistente"
        print("PID registrado:   \(pid) (\(owner))")
    } else {
        print("PID registrado:   ninguno")
    }

    section("Pantallas (coordenadas Cocoa)")
    SystemInfo.screens().forEach { print($0) }
}

/**
 * @brief  Imprime los datos de un elemento que debería ser una ventana.
 *
 * @param[in]  window  Elemento AX.
 * @param[in]  label   Etiqueta con la que se muestra.
 * @return Par (rol del elemento, true si es una ventana con posición y tamaño legibles).
 */
@MainActor
@discardableResult
func describeWindow(_ window: AXUIElement, label: String) -> (role: String?, readable: Bool) {
    let role = AXInspector.string(window, kAXRoleAttribute)
    let position = AXInspector.position(window)
    let size = AXInspector.size(window)
    let title = AXInspector.string(window, kAXTitleAttribute)
    print("  \(label) título:   \(title.describe { Report.redactTitles ? "‹oculto›" : "\"\($0)\"" })")
    print("      rol:      \(role.describe { $0 }) / \(AXInspector.string(window, kAXSubroleAttribute).describe { $0 })")
    print("      posición: \(position.describe { "\(Int($0.x)),\(Int($0.y))" })")
    print("      tamaño:   \(size.describe { "\(Int($0.width))×\(Int($0.height))" })")
    print("      movible:  \(AXInspector.settable(window, kAXPositionAttribute).describe { $0 ? "sí" : "no" })"
          + " · redimensionable: \(AXInspector.settable(window, kAXSizeAttribute).describe { $0 ? "sí" : "no" })")
    let id = AXInspector.windowID(window)
    print("      window id: \(id.describe { "\($0)" })")
    if let value = id.value, let bounds = AXInspector.windowServerBounds(value) {
        print("      WindowServer: \(SystemInfo.format(bounds))")
    }
    let isWindow = role.value == kAXWindowRole
    let readable = isWindow && position.value != nil && (size.value.map { $0.width > 0 && $0.height > 0 } ?? false)
    return (role.value, readable)
}

/**
 * @brief  Mueve una ventana 40 px a la derecha, comprueba el resultado y la devuelve.
 *
 * @param[in]  window  Elemento AX de la ventana.
 * @return Resultado de la prueba.
 */
@MainActor
func moveTest(_ window: AXUIElement) -> MoveOutcome {
    let before = AXInspector.position(window)
    guard let origin = before.value else {
        let reason = "no se puede leer la posición: \(AXInspector.name(before.error))"
        print("    \(reason)")
        return .failed(reason)
    }
    let target = CGPoint(x: origin.x + 40, y: origin.y)
    let set = AXInspector.setPosition(window, target)
    print("    mover a \(Int(target.x)),\(Int(target.y)): \(set.describe { "ok" })")
    settle(0.3)
    let after = AXInspector.position(window)
    print("    posición tras mover: \(after.describe { "\(Int($0.x)),\(Int($0.y))" })")
    if let id = AXInspector.windowID(window).value, let bounds = AXInspector.windowServerBounds(id) {
        print("    WindowServer tras mover: \(SystemInfo.format(bounds))")
    }
    let restore = AXInspector.setPosition(window, origin)
    print("    devolver a \(Int(origin.x)),\(Int(origin.y)): \(restore.describe { "ok" })")

    if set.error != .success {
        return .failed("AXUIElementSetAttributeValue devolvió \(AXInspector.name(set.error))")
    }
    guard let moved = after.value else {
        return .failed("la posición no se puede leer después de mover")
    }
    if abs(moved.x - target.x) <= 2 && abs(moved.y - target.y) <= 2 {
        print("    MUEVE LA VENTANA")
        return .moved
    }
    return .failed("macOS aceptó la orden pero la ventana sigue en \(Int(moved.x)),\(Int(moved.y))")
}

/**
 * @brief  Prueba una vía de acceso: describe sus ventanas y, si se pide, mueve la primera.
 *
 * @param[in]  path     Nombre de la vía.
 * @param[in]  windows  Elementos obtenidos por esa vía.
 * @param[in]  move     Si se hace la prueba de movimiento.
 * @return Lo observado en esa vía.
 */
@MainActor
func probePath(_ path: String, windows: [AXUIElement], move: Bool) -> PathOutcome {
    var outcome = PathOutcome(path: path)
    var firstReadable: AXUIElement?
    for (index, window) in windows.prefix(5).enumerated() {
        let result = describeWindow(window, label: "[\(index)]")
        if result.readable {
            outcome.readable = true
            if firstReadable == nil { firstReadable = window }
        }
    }
    if move {
        print("  Prueba de movimiento (\(path)):")
        if let window = firstReadable {
            outcome.move = moveTest(window)
        } else {
            print("    omitida: ningún elemento es una ventana legible")
            outcome.move = .skipped("ningún elemento es una ventana legible")
        }
    }
    return outcome
}

/**
 * @brief  Inspecciona una app por todas las vías pedidas y compara con WindowServer.
 *
 * @param[in]  app      App en ejecución.
 * @param[in]  options  Opciones de la línea de órdenes.
 * @return Resumen de lo observado.
 */
@MainActor
func inspect(_ app: NSRunningApplication, options: Options) -> AppOutcome {
    let name = app.localizedName ?? app.bundleIdentifier ?? "pid \(app.processIdentifier)"
    let pid = app.processIdentifier
    section("\(name) · pid \(pid)")

    let element = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(element, 2.0)

    let serverWindows = AXInspector.windowServerWindows(pid)
    print("Ventanas según WindowServer: \(serverWindows.count)")
    for window in serverWindows.prefix(5) {
        print("  id \(window.id): \(SystemInfo.format(window.bounds))")
    }

    // Vía 1: AX estándar (lo que usa Rectangle).
    print("\n-- Vía AX estándar (kAXWindowsAttribute)")
    let windows = AXInspector.windows(element)
    print("Ventanas según AX: \(windows.describe { "\($0.count)" })")
    let list = windows.value ?? []
    let fake = list.filter { AXInspector.string($0, kAXRoleAttribute).value == kAXApplicationRole }.count
    if fake > 0 {
        print("ATENCIÓN: \(fake) de \(list.count) «ventanas» responden con rol AXApplication.")
    }
    var paths = [probePath("AX estándar", windows: list, move: options.move)]

    if options.deep {
        // Vía 2: tokens remotos.
        print("\n-- Vía tokens remotos (_AXUIElementCreateWithRemoteToken)")
        let (tokenWindows, ms) = AXInspector.timed { AXInspector.remoteTokenWindows(pid) }
        print("Ventanas encontradas: \(tokenWindows.count)  [\(String(format: "%.0f ms", ms))]")
        paths.append(probePath("tokens remotos", windows: tokenWindows, move: options.move))

        // Vía 3: hit-test en el centro de cada ventana que ve WindowServer.
        print("\n-- Vía hit-test (AXUIElementCopyElementAtPosition)")
        var hitWindows: [AXUIElement] = []
        for window in serverWindows.prefix(3) {
            let center = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
            let hit = AXInspector.windowAt(center)
            print("Centro de id \(window.id) (\(Int(center.x)),\(Int(center.y))): \(hit.describe { _ in "elemento encontrado" })")
            if let value = hit.value { hitWindows.append(value) }
        }
        paths.append(probePath("hit-test", windows: hitWindows, move: options.move))
    }

    var appleEventsMoved: Bool?
    if options.appleEvents, let bundleID = app.bundleIdentifier, !serverWindows.isEmpty {
        print("\n-- Vía Apple Events (sin Accesibilidad)")
        appleEventsMoved = AppleEventsProbe.moveTest(bundleID)
    }

    return AppOutcome(name: name,
                      windowServerWindows: serverWindows.count,
                      fakeWindows: fake,
                      paths: paths,
                      appleEventsMoved: appleEventsMoved)
}

/**
 * @brief  Indica si una vía movió la ventana en la prueba.
 *
 * @param[in]  outcome  Lo observado en la vía.
 * @return true si la ventana se movió.
 */
func moved(_ outcome: PathOutcome) -> Bool {
    if case .moved = outcome.move { return true }
    return false
}

/**
 * @brief  Decide dónde está el fallo a partir de lo observado y lo imprime.
 *
 * @param[in]  trusted   Si este proceso tiene permiso de Accesibilidad.
 * @param[in]  outcomes  Resúmenes de las apps inspeccionadas.
 */
func printVerdict(trusted: Bool, outcomes: [AppOutcome]) {
    section("Veredicto")
    guard trusted else {
        print("Este proceso no tiene permiso de Accesibilidad. Concédeselo a la app")
        print("responsable indicada arriba (o ejecuta con --prompt) y repite la prueba.")
        return
    }
    let withWindows = outcomes.filter { $0.windowServerWindows > 0 }
    guard !withWindows.isEmpty else {
        print("Ninguna app inspeccionada tiene ventanas en pantalla. Abre una ventana")
        print("del Finder y repite la prueba.")
        return
    }

    let standardBroken = withWindows.filter { !($0.paths.first?.readable ?? false) }
    let corrupted = withWindows.filter { $0.fakeWindows > 0 }

    if standardBroken.isEmpty {
        print("AX ESTÁNDAR FUNCIONA en todas las apps inspeccionadas.")
    } else if standardBroken.count == withWindows.count {
        print("AX ESTÁNDAR ROTO EN TODAS LAS APPS: WindowServer ve ventanas, pero AX no")
        print("devuelve ninguna ventana legible. Rectangle no puede moverlas.")
    } else {
        print("AX ESTÁNDAR ROTO EN: \(standardBroken.map(\.name).joined(separator: ", ")).")
    }
    if !corrupted.isEmpty {
        print("Árbol AX corrupto: la lista de ventanas devuelve la propia app (rol")
        print("AXApplication) en: \(corrupted.map(\.name).joined(separator: ", ")).")
    }

    // Vías alternativas.
    for path in ["tokens remotos", "hit-test"] {
        let results = withWindows.compactMap { app in app.paths.first { $0.path == path }.map { (app.name, $0) } }
        guard !results.isEmpty else { continue }
        let ok = results.filter { moved($0.1) || ($0.1.move == nil && $0.1.readable) }.map(\.0)
        print("Vía \(path): funciona en \(ok.count)/\(results.count)\(ok.isEmpty ? "" : " (\(ok.joined(separator: ", ")))").")
    }
    let events = withWindows.compactMap { app in app.appleEventsMoved.map { (app.name, $0) } }
    if !events.isEmpty {
        let ok = events.filter(\.1).map(\.0)
        print("Vía Apple Events: mueve en \(ok.count)/\(events.count)\(ok.isEmpty ? "" : " (\(ok.joined(separator: ", ")))").")
    }
}

// MARK: - Programa principal

let options = parse(Array(CommandLine.arguments.dropFirst()))
if options.help {
    printHelp()
    exit(0)
}
Report.redactTitles = options.redact

let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": options.prompt] as CFDictionary)
AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 2.0)
printSystem(trusted: trusted)

let running = NSWorkspace.shared.runningApplications
let targets: [NSRunningApplication]
if options.all {
    targets = running.filter { $0.activationPolicy == .regular && AXInspector.windowServerCount($0.processIdentifier) > 0 }
} else {
    let ids = options.bundleIDs.isEmpty ? ["com.apple.finder"] : options.bundleIDs
    targets = ids.flatMap { id in
        let matches = running.filter { $0.bundleIdentifier == id }
        if matches.isEmpty { print("\nNo está en ejecución: \(id)") }
        return matches
    }
}

let outcomes = targets.map { inspect($0, options: options) }
printVerdict(trusted: trusted, outcomes: outcomes)
