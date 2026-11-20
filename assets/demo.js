/*
-------------------------------------------------------------------------------
Name:     assets/demo.js
Purpose:  Cierre del selector de idioma y animación de la portada: se pulsan las teclas de un atajo de toc
          (⌃⌥ + tecla) y la ventana dibujada se coloca en su zona. Recorre
          varios atajos en bucle y responde también a los atajos reales del
          teclado. Usa las mismas fórmulas que LayoutEngine, en fracciones.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
*/

(() => {
  "use strict";

  // Cierra el selector de idioma al pulsar fuera de él o la tecla Escape.
  const lang = document.querySelector(".lang");
  if (lang) {
    document.addEventListener("click", (event) => {
      if (lang.open && !lang.contains(event.target)) lang.open = false;
    });
    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && lang.open) { lang.open = false; lang.querySelector("summary").focus(); }
    });
  }

  const demo = document.querySelector("[data-demo]");
  if (!demo) return;

  const zone = demo.querySelector(".sd-zone");
  const mods = [...demo.querySelectorAll(".sd-mod")];
  const key = demo.querySelector(".sd-key");
  const label = demo.querySelector(".sd-label");
  const labels = JSON.parse(demo.querySelector(".demo-labels").textContent);
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /** Tecla visible de cada acción. */
  const KEY_SYMBOL = {
    leftHalf: "←", rightHalf: "→", topHalf: "↑", bottomHalf: "↓",
    topLeft: "U", topRight: "I", bottomLeft: "J", bottomRight: "K",
    firstThird: "D", centerThird: "F", lastThird: "G",
    firstTwoThirds: "E", lastTwoThirds: "T", maximize: "↩", center: "C",
  };

  /** Tecla física (KeyboardEvent.code) de cada acción. */
  const KEYS = {
    ArrowLeft: "leftHalf", ArrowRight: "rightHalf", ArrowUp: "topHalf", ArrowDown: "bottomHalf",
    KeyU: "topLeft", KeyI: "topRight", KeyJ: "bottomLeft", KeyK: "bottomRight",
    KeyD: "firstThird", KeyF: "centerThird", KeyG: "lastThird",
    KeyE: "firstTwoThirds", KeyT: "lastTwoThirds", Enter: "maximize", KeyC: "center",
  };

  /** Recorrido automático. */
  const TOUR = ["rightHalf", "topLeft", "maximize", "firstTwoThirds", "bottomRight", "leftHalf", "center"];

  /** Tiempos del gesto, en milisegundos. */
  const STEP = 2600, PRESS_GAP = 110, MOVE_AT = 380, RELEASE_AT = 820;

  let frame = { x: 0.5, y: 0, w: 0.5, h: 1 };
  let tourIndex = 0;
  let timer = null;
  let pending = [];

  /**
   * @brief  Calcula el marco de destino de una acción, como LayoutEngine.
   *
   * @param[in]  action  Identificador de la acción (string).
   * @param[in]  f       Marco actual {x, y, w, h} en fracciones de la pantalla.
   * @return Marco de destino.
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
      case "center": {
        const w = Math.min(f.w, 0.6), h = Math.min(f.h, 0.6);
        return { x: (1 - w) / 2, y: (1 - h) / 2, w, h };
      }
      default: return f;
    }
  }

  /**
   * @brief  Aplica un marco a la zona mediante variables CSS.
   *
   * @param[in]  f  Marco {x, y, w, h} en fracciones.
   */
  function place(f) {
    zone.style.setProperty("--x", f.x);
    zone.style.setProperty("--y", f.y);
    zone.style.setProperty("--w", f.w);
    zone.style.setProperty("--h", f.h);
  }

  /**
   * @brief  Programa una función y la registra para poder cancelarla.
   *
   * @param[in]  fn     Función a ejecutar.
   * @param[in]  delay  Retardo en milisegundos.
   */
  function later(fn, delay) {
    pending.push(setTimeout(fn, delay));
  }

  /**
   * @brief  Cancela el gesto en curso y suelta las teclas.
   */
  function cancel() {
    pending.forEach(clearTimeout);
    pending = [];
    [...mods, key].forEach((k) => k.classList.remove("down"));
  }

  /**
   * @brief  Representa un atajo: pulsa las teclas, mueve la ventana y las suelta.
   *
   * @param[in]  action  Acción a representar.
   */
  function perform(action) {
    cancel();
    key.textContent = KEY_SYMBOL[action] || "?";
    label.textContent = labels[action] || "";
    const next = target(action, frame);
    if (reducedMotion) {
      frame = next;
      place(frame);
      return;
    }
    mods.forEach((m, i) => later(() => m.classList.add("down"), i * PRESS_GAP));
    later(() => key.classList.add("down"), mods.length * PRESS_GAP);
    later(() => { frame = next; place(frame); }, MOVE_AT);
    later(() => [...mods, key].forEach((k) => k.classList.remove("down")), RELEASE_AT);
  }

  /**
   * @brief  Avanza el recorrido automático.
   */
  function tick() {
    perform(TOUR[tourIndex]);
    tourIndex = (tourIndex + 1) % TOUR.length;
  }

  /**
   * @brief  Arranca (o reinicia) el recorrido automático.
   *
   * @param[in]  delay  Espera antes del primer paso, en milisegundos.
   */
  function startTour(delay) {
    clearInterval(timer);
    timer = null;
    if (reducedMotion) return;
    setTimeout(() => {
      if (timer) return;
      tick();
      timer = setInterval(tick, STEP);
    }, delay);
  }

  // Atajos reales: ⌃⌥ + tecla. Pausan el recorrido unos segundos.
  document.addEventListener("keydown", (event) => {
    if (!(event.ctrlKey && event.altKey) || event.metaKey) return;
    const action = KEYS[event.code];
    if (!action) return;
    event.preventDefault();
    clearInterval(timer);
    timer = null;
    perform(action);
    startTour(6000);
  });

  // Sin animación cuando la portada no se ve, para no gastar batería.
  new IntersectionObserver(([entry]) => {
    if (entry.isIntersecting) {
      if (!timer) startTour(600);
    } else {
      clearInterval(timer);
      timer = null;
    }
  }).observe(demo);

  place(frame);
})();
