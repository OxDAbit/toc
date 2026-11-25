/*
-------------------------------------------------------------------------------
Name:     Sources/toc/LoginItem.swift
Purpose:  Activa o desactiva que toc se abra al iniciar sesión, con
          SMAppService (aparece en Ajustes del Sistema → General → Ítems de
          inicio de sesión).
Version:  v0.0.3
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import ServiceManagement

@MainActor
enum LoginItem {

    /// Si toc está registrado para abrirse al iniciar sesión.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Si macOS espera a que el usuario lo apruebe en Ajustes del Sistema.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /**
     * @brief  Activa o desactiva la apertura al iniciar sesión.
     *
     * @param[in]  enabled  true para activarla, false para desactivarla.
     * @return Mensaje de error, o nil si el cambio se aplicó.
     */
    static func set(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            Log.lifecycle.error("Ítem de inicio de sesión: \(error.localizedDescription, privacy: .public)")
            return error.localizedDescription
        }
    }
}
