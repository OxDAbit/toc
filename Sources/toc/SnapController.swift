/*
-------------------------------------------------------------------------------
Name:     Sources/toc/SnapController.swift
Purpose:  Ajuste al arrastrar: detecta que el usuario arrastra una ventana,
          muestra la vista previa cuando el cursor llega a un borde o esquina
          y, al soltar, aplica la acción. Detecta el arrastre con WindowServer
          (no con Accesibilidad), así que también funciona con el fallo de AX
          tras el reposo; el movimiento final lo hace WindowMover.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

import AppKit
import TocCore

@MainActor
final class SnapController {

    /// Estado del gesto de arrastre.
    private enum DragState {
        case idle
        /// Se pulsó sobre una ventana; aún no se sabe si se está moviendo.
        case candidate(id: CGWindowID, bounds: CGRect)
        /// La ventana se está moviendo con el cursor.
        case dragging(bounds: CGRect)
        /// El gesto no es un arrastre de ventana (por ejemplo, un cambio de tamaño).
        case ignored
    }

    /// Si el ajuste al arrastrar está activo.
    var isEnabled = false {
        didSet { isEnabled ? start() : stop() }
    }

    private var monitor: Any?
    private var state = DragState.idle
    private var pendingAction: WindowAction?
    private let footprint = FootprintWindow()
    private let onSnap: (WindowAction) -> Void

    /// Espera tras soltar, para que la app termine su propio movimiento.
    private let releaseDelay: Duration = .milliseconds(60)

    /**
     * @brief  Crea el controlador, inactivo.
     *
     * @param[in]  onSnap  Se llama con la acción al soltar la ventana en una zona.
     */
    init(onSnap: @escaping (WindowAction) -> Void) {
        self.onSnap = onSnap
    }

    /**
     * @brief  Empieza a observar el ratón en todo el sistema.
     */
    private func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
                let type = event.type
                MainActor.assumeIsolated { self?.handle(type) }
            }
    }

    /**
     * @brief  Deja de observar el ratón.
     */
    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        reset()
    }

    /**
     * @brief  Procesa un evento del ratón.
     *
     * @param[in]  type  Tipo de evento (pulsar, arrastrar o soltar).
     */
    private func handle(_ type: NSEvent.EventType) {
        switch type {
        case .leftMouseDown:
            if let window = WindowServerService.window(at: Self.cursor(), excluding: getpid()) {
                state = .candidate(id: window.id, bounds: window.bounds)
            } else {
                state = .ignored
            }
        case .leftMouseDragged:
            dragged()
        case .leftMouseUp:
            released()
        default:
            break
        }
    }

    /**
     * @brief  Avanza el gesto mientras se arrastra.
     */
    private func dragged() {
        switch state {
        case .candidate(let id, let start):
            guard let now = WindowServerService.bounds(of: id) else {
                state = .ignored
                return
            }
            if now.size != start.size {
                state = .ignored
            } else if now.origin != start.origin {
                state = .dragging(bounds: now)
            }
        case .dragging(let bounds):
            preview(windowBounds: bounds)
        case .idle, .ignored:
            break
        }
    }

    /**
     * @brief  Muestra u oculta la vista previa según la zona en la que está el cursor.
     *
     * @param[in]  windowBounds  Marco de la ventana al empezar a arrastrar.
     */
    private func preview(windowBounds: CGRect) {
        let cursor = Self.cursor()
        let screens = ScreenInfo.current()
        guard let screen = screens.first(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(cursor) }) else {
            setPending(nil, frame: nil)
            return
        }
        let action = SnapArea.action(at: cursor, screen: screen.frame)
        let frame = action.flatMap { LayoutEngine.frame(for: $0, window: windowBounds, visible: screen.visible) }
        setPending(action, frame: frame)
    }

    /**
     * @brief  Guarda la acción pendiente y actualiza la vista previa si ha cambiado.
     *
     * @param[in]  action  Acción de la zona actual, o nil.
     * @param[in]  frame   Marco de destino (origen arriba a la izquierda), o nil.
     */
    private func setPending(_ action: WindowAction?, frame: CGRect?) {
        guard action != pendingAction else { return }
        pendingAction = action
        if let frame {
            footprint.show(Self.cocoa(frame))
        } else {
            footprint.hide()
        }
    }

    /**
     * @brief  Termina el gesto y aplica la acción si la ventana se soltó en una zona.
     */
    private func released() {
        let action: WindowAction?
        if case .dragging = state { action = pendingAction } else { action = nil }
        reset()
        guard let action else { return }
        Task { [weak self, releaseDelay] in
            try? await Task.sleep(for: releaseDelay)
            self?.onSnap(action)
        }
    }

    /**
     * @brief  Vuelve al estado inicial y oculta la vista previa.
     */
    private func reset() {
        state = .idle
        pendingAction = nil
        footprint.hide()
    }

    /**
     * @brief  Posición del cursor en coordenadas de Accesibilidad.
     *
     * @return Punto con origen arriba a la izquierda de la pantalla principal.
     */
    private static func cursor() -> CGPoint {
        let location = NSEvent.mouseLocation
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: location.x, y: primaryHeight - location.y)
    }

    /**
     * @brief  Convierte un marco de coordenadas de Accesibilidad a Cocoa.
     *
     * @param[in]  frame  Marco con origen arriba a la izquierda.
     * @return Marco con origen abajo a la izquierda.
     */
    private static func cocoa(_ frame: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }
}
