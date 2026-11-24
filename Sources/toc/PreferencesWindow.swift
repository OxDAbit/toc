/*
-------------------------------------------------------------------------------
Name:     Sources/toc/PreferencesWindow.swift
Purpose:  Ventana de preferencias de toc (SwiftUI): pestaña «Atajos», con la
          lista de acciones para mostrarlas u ocultarlas en el menú y cambiar
          su atajo, y pestaña «General», con el ajuste al arrastrar y la
          apertura al iniciar sesión.
Version:  v0.0.2
Author:   David Alvarez Medina aka 0xDA_bit
Created:  24/11/2026
-------------------------------------------------------------------------------
*/

import AppKit
import SwiftUI
import TocCore

@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {

    private let store: PreferencesStore
    private var window: NSWindow?

    /**
     * @brief  Crea el controlador; la ventana se crea al abrirla por primera vez.
     *
     * @param[in]  store  Preferencias que muestra y modifica la ventana.
     */
    init(store: PreferencesStore) {
        self.store = store
        super.init()
    }

    /// Tamaño ideal del contenido; se reduce si la pantalla es más pequeña.
    private let idealSize = NSSize(width: 600, height: 700)
    /// Margen mínimo entre la ventana y los bordes de la zona útil de la pantalla.
    private let screenMargin: CGFloat = 40

    /**
     * @brief  Abre la ventana de preferencias, centrada, y la trae al frente.
     */
    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: PreferencesView(store: store))
            // El tamaño lo decide la ventana (según la pantalla), no el contenido.
            hosting.sizingOptions = []
            let window = NSWindow(contentViewController: hosting)
            window.title = "Preferencias de toc"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        }
        store.refreshLogin()
        if let window { center(window) }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /**
     * @brief  Ajusta el tamaño de la ventana a la pantalla y la centra en ella.
     *
     * Usa la pantalla en la que está el cursor (la del menú que se acaba de
     * pulsar) y su zona útil, sin barra de menús ni Dock. NSWindow.center()
     * no sirve: deja la ventana algo por encima del centro.
     *
     * @param[in]  window  Ventana de preferencias.
     */
    private func center(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
                ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let content = NSSize(width: min(idealSize.width, visible.width - 2 * screenMargin),
                             height: min(idealSize.height, visible.height - 2 * screenMargin))
        let size = window.frameRect(forContentRect: NSRect(origin: .zero, size: content)).size
        let origin = NSPoint(x: (visible.midX - size.width / 2).rounded(),
                             y: (visible.midY - size.height / 2).rounded())
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    /**
     * @brief  Cancela la grabación de un atajo si se cierra la ventana a medias.
     *
     * @param[in]  notification  Notificación de cierre (no se usa).
     */
    func windowWillClose(_ notification: Notification) {
        store.stopRecording()
    }
}

/// Contenido de la ventana de preferencias.
struct PreferencesView: View {
    let store: PreferencesStore

    var body: some View {
        TabView {
            ShortcutsPane(store: store)
                .tabItem { Label("Atajos", systemImage: "keyboard") }
            GeneralPane(store: store)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(minWidth: 480, maxWidth: .infinity, minHeight: 360, maxHeight: .infinity)
        .padding(.top, 8)
    }
}

/// Pestaña «Atajos»: una fila por acción, agrupadas como en el menú.
struct ShortcutsPane: View {
    let store: PreferencesStore

    /// Grupos de acciones en el orden del menú.
    private var groups: [Int] {
        Array(Set(WindowAction.allCases.map(\.group))).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Marca las acciones que quieres ver en el menú y haz clic en un atajo para cambiarlo. "
                 + "Esc cancela y ⌫ deja la acción sin atajo.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            Form {
                ForEach(groups, id: \.self) { group in
                    Section(WindowAction.groupTitle(group)) {
                        ForEach(WindowAction.allCases.filter { $0.group == group }, id: \.self) { action in
                            ActionRow(store: store, action: action)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                if let notice = store.lastNotice {
                    Label(notice, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Restablecer todos los atajos") { store.resetAllShortcuts() }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
    }
}

/// Fila de una acción: visible en el menú, icono, nombre, atajo y restablecer.
struct ActionRow: View {
    let store: PreferencesStore
    let action: WindowAction

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Mostrar en el menú", isOn: Binding(
                get: { store.isVisible(action) },
                set: { store.setVisible($0, for: action) }))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .help("Mostrar en el menú")
            Image(nsImage: MenuIcon.image(for: action))
            Text(action.title)
            if store.failedActions.contains(action.rawValue) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("Otra app usa este atajo: toc no lo puede registrar")
            }
            Spacer()
            ShortcutRecorder(store: store, action: action)
            Button {
                store.reset(action)
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help("Restablecer el atajo por defecto")
            .opacity(store.preferences.isCustomized(action) ? 1 : 0)
            .disabled(!store.preferences.isCustomized(action))
        }
    }
}

/// Botón que muestra el atajo de una acción y, al pulsarlo, graba uno nuevo.
struct ShortcutRecorder: View {
    let store: PreferencesStore
    let action: WindowAction

    private var isRecording: Bool { store.recordingAction == action }

    private var label: String {
        if isRecording { return store.recordingHint ?? "Pulsa el atajo…" }
        _ = store.layoutRevision
        return store.shortcut(for: action).map(KeyEquivalent.display) ?? "Sin atajo"
    }

    var body: some View {
        Button {
            store.toggleRecording(action)
        } label: {
            Text(label)
                .frame(minWidth: 120)
                .foregroundStyle(isRecording || store.shortcut(for: action) != nil ? .primary : .secondary)
        }
        .buttonStyle(.bordered)
        .tint(isRecording ? .accentColor : nil)
        .help(isRecording ? "Esc cancela · ⌫ deja la acción sin atajo" : "Haz clic para cambiar el atajo")
    }
}

/// Pestaña «General»: ajuste al arrastrar, apertura al iniciar sesión y versión.
struct GeneralPane: View {
    let store: PreferencesStore
    @State private var loginError: String?

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        Form {
            Section("Ventanas") {
                Toggle("Ajustar al arrastrar a los bordes", isOn: Binding(
                    get: { store.snapEnabled },
                    set: { store.setSnapEnabled($0) }))
                Text("Lleva una ventana a un borde o a una esquina de la pantalla para colocarla al soltarla.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Inicio") {
                Toggle("Abrir al iniciar sesión", isOn: Binding(
                    get: { store.loginEnabled },
                    set: { loginError = store.setLoginEnabled($0) }))
                if store.loginPending {
                    Text("Pendiente de aprobar en Ajustes del Sistema → General → Ítems de inicio de sesión.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Section {
                LabeledContent("Versión", value: version)
            }
        }
        .formStyle(.grouped)
    }
}
