/*
-------------------------------------------------------------------------------
Name:     assets/demo.js
Purpose:  Demo interactiva de la portada: una ventana que se coloca con los
          mismos atajos que toc (⌃⌥ + tecla), con botones o arrastrándola a
          los bordes de una pantalla dibujada. Usa las mismas fórmulas que
          LayoutEngine, en fracciones de la zona útil.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

(() => {
  "use strict";

  const demo = document.querySelector("[data-demo]");
  if (!demo) return;

  const area = demo.querySelector(".demo-area");
  const win = demo.querySelector(".demo-window");
  const footprint = demo.querySelector(".demo-footprint");
  const status = demo.querySelector(".demo-status");
  const buttons = [...demo.querySelectorAll("[data-action]")];
  const labels = JSON.parse(demo.querySelector(".demo-labels").textContent);
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /** Atajo de cada acción, para mostrarlo en el estado. */
  const SHORTCUTS = {
    leftHalf: "⌃⌥←", rightHalf: "⌃⌥→", topHalf: "⌃⌥↑", bottomHalf: "⌃⌥↓",
    topLeft: "⌃⌥U", topRight: "⌃⌥I", bottomLeft: "⌃⌥J", bottomRight: "⌃⌥K",
    firstThird: "⌃⌥D", centerThird: "⌃⌥F", lastThird: "⌃⌥G",
    firstTwoThirds: "⌃⌥E", lastTwoThirds: "⌃⌥T", maximize: "⌃⌥↩",
    maximizeHeight: "⌃⌥⇧↑", center: "⌃⌥C", restore: "⌃⌥⌫",
  };

  /** Tecla física (KeyboardEvent.code) de cada acción. */
  const KEYS = {
    ArrowLeft: "leftHalf", ArrowRight: "rightHalf", ArrowUp: "topHalf", ArrowDown: "bottomHalf",
    KeyU: "topLeft", KeyI: "topRight", KeyJ: "bottomLeft", KeyK: "bottomRight",
    KeyD: "firstThird", KeyF: "centerThird", KeyG: "lastThird",
    KeyE: "firstTwoThirds", KeyT: "lastTwoThirds", Enter: "maximize",
    KeyC: "center", Backspace: "restore",
  };

  let frame = { x: 0.32, y: 0.16, w: 0.36, h: 0.6 };
  let previous = null;
  let touched = false;

  /**
   * @brief  Calcula el marco de destino de una acción, como LayoutEngine.
   *
   * @param[in]  action  Identificador de la acción (string).
   * @param[in]  f       Marco actual {x, y, w, h} en fracciones de la zona útil.
   * @return Marco de destino, o null si la acción no cambia nada.
   */
  function target(action, f) {
    const t = 1 / 3;
    switch (action) {
      case "leftHalf": return { x: 0, y: 0, w: 0.5, h: 1 };
      case "rightHalf": return { x: 0.5, y: 0, w: 0.5, h: 1 };
      case "topHalf": return { x: 0, y: 0, w: 1, h: 0.5 };
      case "bottomHalf": return { x: 0, y: 0.5, w: 1, h: 0.5 };
      case "topLeft": return { x: 0, y: 0, w: 0.5, h: 0.5 };
      case "topRight": return { x: 0.5, y: 0, w: 0.5, h: 0.5 };
      case "bottomLeft": return { x: 0, y: 0.5, w: 0.5, h: 0.5 };
      case "bottomRight": return { x: 0.5, y: 0.5, w: 0.5, h: 0.5 };
      case "firstThird": return { x: 0, y: 0, w: t, h: 1 };
      case "centerThird": return { x: t, y: 0, w: t, h: 1 };
      case "lastThird": return { x: 2 * t, y: 0, w: t, h: 1 };
      case "firstTwoThirds": return { x: 0, y: 0, w: 2 * t, h: 1 };
      case "lastTwoThirds": return { x: t, y: 0, w: 2 * t, h: 1 };
      case "maximize": return { x: 0, y: 0, w: 1, h: 1 };
      case "maximizeHeight": return { x: f.x, y: 0, w: f.w, h: 1 };
      case "center": return { x: (1 - f.w) / 2, y: (1 - f.h) / 2, w: f.w, h: f.h };
      default: return null;
    }
  }

  /**
   * @brief  Aplica un marco a un elemento mediante variables CSS.
   *
   * @param[in]  el  Elemento (ventana o vista previa).
   * @param[in]  f   Marco {x, y, w, h} en fracciones.
   */
  function place(el, f) {
    el.style.setProperty("--x", f.x);
    el.style.setProperty("--y", f.y);
    el.style.setProperty("--w", f.w);
    el.style.setProperty("--h", f.h);
  }

  /**
   * @brief  Muestra en el estado la acción realizada y su atajo.
   *
   * @param[in]  text      Texto principal.
   * @param[in]  shortcut  Atajo a mostrar, opcional.
   */
  function say(text, shortcut) {
    status.textContent = text + " ";
    if (shortcut) {
      for (const key of shortcut) {
        const kbd = document.createElement("kbd");
        kbd.textContent = key;
        status.append(kbd);
      }
    }
  }

  /**
   * @brief  Ejecuta una acción sobre la ventana de la demo.
   *
   * @param[in]  action  Identificador de la acción.
   */
  function run(action) {
    if (action === "restore") {
      if (!previous) { say(labels._empty); return; }
      frame = previous;
      previous = null;
    } else {
      const next = target(action, frame);
      if (!next) return;
      if (!previous) previous = { ...frame };
      frame = next;
    }
    place(win, frame);
    say(labels[action], SHORTCUTS[action]);
    buttons.forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.action === action)));
  }

  /**
   * @brief  Marca que el usuario ha interactuado y detiene la presentación automática.
   */
  function interact() { touched = true; }

  buttons.forEach((button) =>
    button.addEventListener("click", () => { interact(); run(button.dataset.action); }));

  // Atajos de teclado: ⌃⌥ + tecla en toda la página (si toc está abierto, el
  // propio toc los captura antes y moverá tu ventana de verdad), o la tecla
  // sola cuando la ventana de la demo tiene el foco.
  document.addEventListener("keydown", (event) => {
    const focused = document.activeElement === win;
    const combo = event.ctrlKey && event.altKey && !event.metaKey;
    if (!combo && !focused) return;
    let action = KEYS[event.code];
    if (event.code === "ArrowUp" && event.shiftKey) action = "maximizeHeight";
    if (!action) return;
    event.preventDefault();
    interact();
    run(action);
  });

  // ---------- Arrastrar a los bordes ----------

  const EDGE = 0.025;   // franja del borde, en fracción del ancho o alto
  const CORNER = 0.1;   // tamaño de las esquinas

  /**
   * @brief  Decide la zona de ajuste según la posición del puntero, como SnapArea.
   *
   * @param[in]  px  Posición horizontal en fracción de la pantalla (0–1).
   * @param[in]  py  Posición vertical en fracción de la zona útil (puede ser < 0 en la barra de menús).
   * @return Acción de la zona, o null.
   */
  function snapArea(px, py) {
    const left = px <= EDGE, right = px >= 1 - EDGE, top = py <= EDGE, bottom = py >= 1 - EDGE;
    const nearLeft = px <= CORNER, nearRight = px >= 1 - CORNER;
    const nearTop = py <= CORNER, nearBottom = py >= 1 - CORNER;
    if ((left && nearTop) || (top && nearLeft)) return "topLeft";
    if ((right && nearTop) || (top && nearRight)) return "topRight";
    if ((left && nearBottom) || (bottom && nearLeft)) return "bottomLeft";
    if ((right && nearBottom) || (bottom && nearRight)) return "bottomRight";
    if (top) return "maximize";
    if (left) return "leftHalf";
    if (right) return "rightHalf";
    return null;
  }

  let drag = null;
  let pending = null;

  win.querySelector(".demo-titlebar").addEventListener("pointerdown", (event) => {
    interact();
    const box = area.getBoundingClientRect();
    drag = { box, dx: (event.clientX - box.left) / box.width - frame.x, dy: (event.clientY - box.top) / box.height - frame.y };
    win.classList.add("dragging");
    win.setPointerCapture(event.pointerId);
  });

  win.addEventListener("pointermove", (event) => {
    if (!drag) return;
    const { box } = drag;
    const px = (event.clientX - box.left) / box.width;
    const py = (event.clientY - box.top) / box.height;
    frame = {
      ...frame,
      x: Math.min(Math.max(px - drag.dx, -frame.w * 0.7), 1 - frame.w * 0.3),
      y: Math.min(Math.max(py - drag.dy, 0), 1 - 0.08),
    };
    place(win, frame);
    const action = snapArea(Math.min(Math.max(px, 0), 1), Math.min(Math.max(py, 0), 1));
    if (action !== pending) {
      pending = action;
      if (action) { place(footprint, target(action, frame)); footprint.hidden = false; }
      else footprint.hidden = true;
    }
  });

  /**
   * @brief  Termina el arrastre y coloca la ventana si se soltó en una zona.
   */
  function endDrag() {
    if (!drag) return;
    drag = null;
    win.classList.remove("dragging");
    footprint.hidden = true;
    if (pending) {
      const action = pending;
      pending = null;
      previous = null;
      run(action);
    }
  }
  win.addEventListener("pointerup", endDrag);
  win.addEventListener("pointercancel", endDrag);

  // ---------- Presentación inicial ----------
  // Un único recorrido corto al cargar, que se detiene en cuanto el usuario
  // toca algo. Con «reducir movimiento» no se reproduce.
  if (!reducedMotion) {
    const tour = ["rightHalf", "topLeft", "maximize", "firstTwoThirds"];
    let step = 0;
    const timer = setInterval(() => {
      if (touched || step >= tour.length) { clearInterval(timer); return; }
      run(tour[step++]);
    }, 1100);
  }
})();
