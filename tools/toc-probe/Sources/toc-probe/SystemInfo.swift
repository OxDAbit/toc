/*
-------------------------------------------------------------------------------
Name:     tools/toc-probe/Sources/toc-probe/SystemInfo.swift
Purpose:  Datos del sistema que acompañan al diagnóstico: versión de macOS,
          arquitectura, horas de arranque, reposo y despertar, estado de la
          Entrada Segura, pantallas y app responsable del permiso.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit
import Carbon
import Darwin
import IOKit

@MainActor
enum SystemInfo {

    /**
     * @brief  Devuelve la versión de macOS tal como la muestra el sistema.
     *
     * @return Cadena con versión y build, por ejemplo "Version 26.7.1 (Build 25G241)".
     */
    static func osVersion() -> String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    /**
     * @brief  Devuelve la arquitectura de la máquina (x86_64 o arm64).
     *
     * @return Nombre de la arquitectura según uname.
     */
    static func machine() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    /**
     * @brief  Lee una marca de tiempo del kernel (kern.boottime, kern.waketime…).
     *
     * @param[in]  name  Nombre de la entrada sysctl que contiene un struct timeval.
     * @return Fecha leída, o nil si la entrada no existe o vale cero.
     */
    static func kernelDate(_ name: String) -> Date? {
        var value = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0, value.tv_sec > 0 else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(value.tv_sec))
    }

    /**
     * @brief  Indica si la Entrada Segura del teclado está activa en la sesión.
     *
     * @return true si alguna app tiene activada la Entrada Segura.
     */
    static func secureInputEnabled() -> Bool {
        IsSecureEventInputEnabled()
    }

    /**
     * @brief  Lee el PID que el registro de E/S asocia a la Entrada Segura.
     *
     * El valor puede quedarse apuntando a un proceso que ya no existe; por eso
     * se informa aparte de si la Entrada Segura está realmente activa.
     *
     * @return PID registrado en kCGSSessionSecureInputPID, o nil si no hay ninguno.
     */
    static func secureInputPID() -> pid_t? {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        defer { IOObjectRelease(root) }
        guard
            let property = IORegistryEntryCreateCFProperty(
                root, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue(),
            let users = property as? [[String: Any]]
        else {
            return nil
        }
        for user in users {
            if let pid = user["kCGSSessionSecureInputPID"] as? Int {
                return pid_t(pid)
            }
        }
        return nil
    }

    /**
     * @brief  Devuelve el nombre de un proceso a partir de su PID.
     *
     * @param[in]  pid  Identificador del proceso.
     * @return Nombre de la app o del ejecutable, o nil si el proceso no existe.
     */
    static func processName(_ pid: pid_t) -> String? {
        if let app = NSRunningApplication(processIdentifier: pid), let name = app.localizedName {
            return name
        }
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else {
            return nil
        }
        let path = buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        return (path as NSString).lastPathComponent
    }

    /**
     * @brief  Devuelve el PID del proceso padre.
     *
     * @param[in]  pid  Identificador del proceso hijo.
     * @return PID del padre, o nil si no se puede leer.
     */
    static func parentPID(_ pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else {
            return nil
        }
        return pid_t(info.pbi_ppid)
    }

    /**
     * @brief  Busca la app (con bundle) de la que cuelga este proceso.
     *
     * macOS concede el permiso de Accesibilidad a esa app (por ejemplo, el
     * terminal), no al ejecutable de la sonda.
     *
     * @return Nombre e identificador de la app responsable, o nil si no se encuentra.
     */
    static func responsibleApp() -> String? {
        var pid = getpid()
        for _ in 0..<16 {
            if let app = NSRunningApplication(processIdentifier: pid), app.bundleURL != nil {
                let name = app.localizedName ?? "?"
                let bundle = app.bundleIdentifier ?? "?"
                return "\(name) (\(bundle))"
            }
            guard let parent = parentPID(pid), parent > 1 else {
                return nil
            }
            pid = parent
        }
        return nil
    }

    /**
     * @brief  Describe las pantallas conectadas en coordenadas de Cocoa.
     *
     * @return Una línea por pantalla con nombre, marco y zona útil.
     */
    static func screens() -> [String] {
        NSScreen.screens.enumerated().map { index, screen in
            "\(index): \(screen.localizedName) frame=\(format(screen.frame)) visible=\(format(screen.visibleFrame))"
        }
    }

    /**
     * @brief  Formatea un rectángulo como (x, y, ancho, alto) sin decimales.
     *
     * @param[in]  rect  Rectángulo a formatear.
     * @return Cadena legible.
     */
    static func format(_ rect: CGRect) -> String {
        String(format: "(%.0f, %.0f, %.0f×%.0f)",
               rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)
    }
}
