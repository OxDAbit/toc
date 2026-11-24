/*
-------------------------------------------------------------------------------
Name:     Sources/toc/HotkeyService.swift
Purpose:  Atajos de teclado globales con Carbon (RegisterEventHotKey), que no
          necesitan leer todo el teclado y siguen funcionando con la Entrada
          Segura activa. Se vuelven a registrar al despertar del reposo.
Version:  v0.0.2
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import Carbon
import TocCore

/// Atajo con su identificador, su nombre (para los avisos) y lo que ejecuta.
struct HotkeyBinding {
    let id: String
    let shortcut: Shortcut
    let name: String
    let action: @MainActor () -> Void
}

@MainActor
final class HotkeyService {

    /// Instancia que recibe los eventos del manejador de Carbon.
    static weak var active: HotkeyService?
    /// Firma de los atajos de toc ('TocK').
    private static let signature: OSType = 0x546F_634B

    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: @MainActor () -> Void] = [:]
    private var handlerRef: EventHandlerRef?
    private var bindings: [HotkeyBinding] = []
    /// Atajos que no se pudieron registrar (normalmente, ocupados por otra app).
    private(set) var failed: [String] = []
    /// Identificadores de los atajos que no se pudieron registrar.
    private(set) var failedIDs: Set<String> = []

    /**
     * @brief  Instala el manejador de eventos de Carbon.
     */
    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &spec, nil, &handlerRef)
        if status != noErr {
            Log.hotkeys.error("No se pudo instalar el manejador de atajos: \(status)")
        }
        HotkeyService.active = self
    }

    /**
     * @brief  Registra un conjunto de atajos, sustituyendo los anteriores.
     *
     * @param[in]  bindings  Atajos a registrar.
     */
    func register(_ bindings: [HotkeyBinding]) {
        self.bindings = bindings
        reregister()
    }

    /**
     * @brief  Vuelve a registrar los últimos atajos (por ejemplo, al despertar).
     */
    func reregister() {
        unregisterAll()
        for (index, binding) in bindings.enumerated() {
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(index + 1))
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(binding.shortcut.keyCode, binding.shortcut.modifiers.carbonFlags,
                                             id, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                refs.append(ref)
                actions[id.id] = binding.action
            } else {
                failed.append("\(binding.name) (\(KeyEquivalent.display(binding.shortcut)))")
                failedIDs.insert(binding.id)
                Log.hotkeys.error("Atajo no disponible \(KeyEquivalent.display(binding.shortcut)): \(status)")
            }
        }
        Log.hotkeys.info("Atajos registrados: \(self.refs.count), fallidos: \(self.failed.count)")
    }

    /**
     * @brief  Elimina todos los atajos registrados.
     */
    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        actions.removeAll()
        failed.removeAll()
        failedIDs.removeAll()
    }

    /**
     * @brief  Ejecuta la acción asociada a un atajo pulsado.
     *
     * @param[in]  id  Identificador del atajo.
     */
    func fire(_ id: UInt32) {
        actions[id]?()
    }
}

/**
 * @brief  Manejador de Carbon que recibe la pulsación de un atajo.
 *
 * @param[in]  next      Siguiente manejador de la cadena (no se usa).
 * @param[in]  event     Evento de Carbon con el identificador del atajo.
 * @param[in]  userData  Datos de usuario (no se usan).
 * @return noErr si se ha atendido el evento.
 */
private func hotKeyHandler(_ next: EventHandlerCallRef?, _ event: EventRef?,
                           _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var id = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                   EventParamType(typeEventHotKeyID), nil,
                                   MemoryLayout<EventHotKeyID>.size, nil, &id)
    guard status == noErr else { return status }
    MainActor.assumeIsolated {
        HotkeyService.active?.fire(id.id)
    }
    return noErr
}
