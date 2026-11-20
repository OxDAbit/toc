# -------------------------------------------------------------------------------
# Name:     tools/build.py
# Purpose:  Genera la web de presentación de toc en castellano (index.html) y en
#           inglés (en/index.html) a partir de una única plantilla, con los
#           iconos de cada acción calculados igual que en LayoutEngine.
#           Uso: python3 tools/build.py (desde la raíz de la rama gh-pages).
# Version:  v0.0.1
# Author:   David Alvarez Medina aka 0xDA_bit
# Created:  20/11/2026
# -------------------------------------------------------------------------------

import hashlib
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO = "https://github.com/OxDAbit/toc"
VERSION = "0.0.1"

# Acciones en el orden y los grupos del menú de toc, con su atajo por defecto.
# Cada tupla: (id, grupo, atajo o None, nombre es, nombre en).
ACTIONS = [
    ("leftHalf", 0, "⌃⌥←", "Mitad izquierda", "Left half"),
    ("rightHalf", 0, "⌃⌥→", "Mitad derecha", "Right half"),
    ("centerHalf", 0, None, "Mitad central", "Center half"),
    ("topHalf", 0, "⌃⌥↑", "Mitad superior", "Top half"),
    ("bottomHalf", 0, "⌃⌥↓", "Mitad inferior", "Bottom half"),
    ("topLeft", 1, "⌃⌥U", "Arriba a la izquierda", "Top left"),
    ("topRight", 1, "⌃⌥I", "Arriba a la derecha", "Top right"),
    ("bottomLeft", 1, "⌃⌥J", "Abajo a la izquierda", "Bottom left"),
    ("bottomRight", 1, "⌃⌥K", "Abajo a la derecha", "Bottom right"),
    ("firstThird", 2, "⌃⌥D", "Primer tercio", "First third"),
    ("centerThird", 2, "⌃⌥F", "Tercio central", "Center third"),
    ("lastThird", 2, "⌃⌥G", "Último tercio", "Last third"),
    ("firstTwoThirds", 2, "⌃⌥E", "Primeros dos tercios", "First two thirds"),
    ("centerTwoThirds", 2, None, "Dos tercios centrales", "Center two thirds"),
    ("lastTwoThirds", 2, "⌃⌥T", "Últimos dos tercios", "Last two thirds"),
    ("maximize", 3, "⌃⌥↩", "Maximizar", "Maximize"),
    ("almostMaximize", 3, None, "Casi maximizar", "Almost maximize"),
    ("maximizeHeight", 3, "⌃⌥⇧↑", "Maximizar altura", "Maximize height"),
    ("center", 3, "⌃⌥C", "Centrar", "Center"),
    ("restore", 3, "⌃⌥⌫", "Restaurar", "Restore"),
]

# Acciones que se pueden probar con los botones de la demo.
# Contador para que cada icono tenga un clipPath con id único en la página.
_icon_ids = iter(range(1, 10_000))

DEMO_KEYS = ["leftHalf", "rightHalf", "topHalf", "bottomHalf", "topLeft", "topRight",
             "bottomLeft", "bottomRight", "firstThird", "lastTwoThirds", "maximize", "center", "restore"]


## @brief  Calcula la zona de destino de una acción, igual que LayoutEngine.
#
#  @param[in]  action  Identificador de la acción (str).
#  @param[in]  win     Marco actual (x, y, ancho, alto) como tupla de float.
#  @param[in]  vis     Zona útil (x, y, ancho, alto) como tupla de float.
#  @return Tupla (x, y, ancho, alto), o None para "restore".
def zone(action, win, vis):
    x, y, w, h = vis
    hw, hh, tw = w / 2, h / 2, w / 3
    table = {
        "leftHalf": (x, y, hw, h), "rightHalf": (x + hw, y, hw, h),
        "centerHalf": (x + w / 4, y, hw, h), "topHalf": (x, y, w, hh),
        "bottomHalf": (x, y + hh, w, hh), "topLeft": (x, y, hw, hh),
        "topRight": (x + hw, y, hw, hh), "bottomLeft": (x, y + hh, hw, hh),
        "bottomRight": (x + hw, y + hh, hw, hh), "firstThird": (x, y, tw, h),
        "centerThird": (x + tw, y, tw, h), "lastThird": (x + 2 * tw, y, tw, h),
        "firstTwoThirds": (x, y, 2 * tw, h), "centerTwoThirds": (x + tw / 2, y, 2 * tw, h),
        "lastTwoThirds": (x + tw, y, 2 * tw, h), "maximize": (x, y, w, h),
        "almostMaximize": (x + w * .05, y + h * .05, w * .9, h * .9),
        "maximizeHeight": (win[0], y, win[2], h),
        "center": (x + (w - min(win[2], w)) / 2, y + (h - min(win[3], h)) / 2,
                   min(win[2], w), min(win[3], h)),
    }
    return table.get(action)


## @brief  Dibuja el icono SVG de una acción (pantalla con su zona en azul).
#
#  @param[in]  action  Identificador de la acción (str).
#  @return Código SVG en línea (str).
def icon(action):
    sx, sy, sw, sh = 1.0, 1.5, 20.0, 13.0
    uid = f"c{next(_icon_ids)}"
    body = ""
    if action == "restore":
        body = ('<path class="i-arrow" d="M8.6 6.2 6.4 8.2l2.2 2M6.6 8.2h6.2a2.4 2.4 0 0 1 0 4.8h-1.6"/>')
    else:
        if action == "almostMaximize":
            zx, zy, zw, zh = sx + 2.5, sy + 2.5, sw - 5, sh - 5
        else:
            cx, cy, cw, ch = zone(action, (30, 22, 60, 46), (0, 0, 120, 90))
            zx, zy = sx + cx / 120 * sw, sy + cy / 90 * sh
            zw, zh = cw / 120 * sw, ch / 90 * sh
        body = f'<rect class="i-zone" x="{zx:.2f}" y="{zy:.2f}" width="{zw:.2f}" height="{zh:.2f}"/>'
    return (f'<svg class="icon" viewBox="0 0 22 16" aria-hidden="true">'
            f'<defs><clipPath id="{uid}"><rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" rx="2.5"/></clipPath></defs>'
            f'<g clip-path="url(#{uid})"><rect class="i-bg" x="{sx}" y="{sy}" width="{sw}" height="{sh}"/>'
            f'{body if action != "restore" else ""}</g>'
            f'{body if action == "restore" else ""}'
            f'<rect class="i-frame" x="{sx}" y="{sy}" width="{sw}" height="{sh}" rx="2.5"/></svg>')


## @brief  Escribe un atajo como teclas individuales.
#
#  @param[in]  shortcut  Atajo, por ejemplo "⌃⌥←" (str).
#  @return HTML con un <kbd> por tecla (str).
def keys(shortcut):
    return "".join(f"<kbd>{html.escape(k)}</kbd>" for k in shortcut)


# Textos de la página. Las claves con HTML ya vienen escapadas a mano.
TEXT = {
    "es": {
        "lang": "es", "path": "", "other_href": "en/", "other_lang": "en", "other": "English",
        "title": "toc: coloca tus ventanas en macOS",
        "description": "toc es una app de la barra de menús para macOS que coloca la ventana activa en mitades, "
                       "tercios o cuartos de la pantalla con un atajo o arrastrándola a un borde.",
        "h1": "Cada ventana, en su sitio.",
        "lede": "toc vive en la barra de menús de tu Mac y coloca la ventana activa en mitades, tercios o "
                "cuartos de la pantalla con un atajo de teclado, o arrastrándola hasta un borde.",
        "download": "Descargar toc", "build": "Compilar desde el código",
        "requirements": "Para macOS 26 o posterior, en Mac con Intel o Apple Silicon. Versión " + VERSION + ".",
        "demo_label": "Demostración de toc",
        "demo_hint": "Pulsa ⌃⌥ y una flecha para probarlo aquí. Con toc abierto, moverás tu ventana de verdad.",
        "demo_window": "Notas",
        "demo_ready": "Listo para probar",
        "demo_restore_empty": "No hay ninguna posición anterior",
        "shortcuts_h2": "Veinte posiciones, cada una con su atajo",
        "shortcuts_p": "Son los mismos atajos que usa Rectangle, así que no tienes que aprender nada nuevo. "
                       "En el menú de toc cada acción lleva un icono que muestra dónde quedará la ventana.",
        "shortcuts_none": "sin atajo",
        "drag_h2": "Arrastra hasta el borde",
        "drag_p": "Lleva una ventana hasta el borde de la pantalla y toc te enseña dónde va a quedar. "
                  "Suéltala y se coloca sola.",
        "drag_left": "Bordes laterales", "drag_left_d": "mitad izquierda o derecha",
        "drag_top": "Borde superior", "drag_top_d": "maximizar",
        "drag_corner": "Esquinas", "drag_corner_d": "un cuarto de pantalla",
        "drag_note": "Si estás cambiando el tamaño de una ventana desde su borde, toc no interviene.",
        "drag_svg_top": "maximizar", "drag_svg_side": "mitad", "drag_svg_corner": "cuarto",
        "sleep_h2": "No se queda callada después del reposo",
        "sleep_p": "En algunos Mac con macOS 26, al salir del reposo, macOS deja de dar acceso a las ventanas "
                   "a las apps de Accesibilidad. Los gestores de ventanas dejan de responder sin explicar por qué, "
                   "y solo se arregla reiniciando. toc nació para no quedarse callada cuando pasa.",
        "sleep_steps": [
            "El Mac despierta y, a los tres segundos, toc comprueba que Accesibilidad responde.",
            "Si macOS devuelve la app en lugar de sus ventanas, el icono de toc cambia a ⚠︎ y te explica qué ocurre.",
            "Finder, Safari, Ajustes del Sistema y las demás apps scriptables se siguen moviendo mediante Apple Events.",
            "Para el resto, toc te dice cómo recuperarlo: reiniciar el Mac, porque cerrar sesión no basta.",
        ],
        "sleep_diag": "Si quieres investigarlo, «Copiar diagnóstico» en el menú de toc te da un informe con lo que ve macOS.",
        "install_h2": "Instalar toc",
        "dl_h3": "Descarga",
        "dl_p": "Las versiones publicadas están en la página de versiones del repositorio en GitHub.",
        "dl_button": "Ver versiones en GitHub",
        "dl_note": "toc está firmada con un certificado propio, no con uno de Apple. La primera vez que la abras, "
                   "macOS la bloqueará: ve a Ajustes del Sistema → Privacidad y seguridad y pulsa «Abrir igualmente».",
        "src_h3": "Compila desde el código",
        "src_p": "Necesitas macOS 26 y Xcode 26. El script compila un binario universal, lo firma y lo copia a Aplicaciones.",
        "src_steps": ["Clona el repositorio:", "Entra en la carpeta:", "Compila e instala:", "Abre toc:"],
        "after_h3": "Después de instalar",
        "after_p": "Concede a toc el permiso de Accesibilidad cuando te lo pida. Para que se abra al encender el Mac, "
                   "marca «Abrir al iniciar sesión» en su menú.",
        "footer_meta": "toc v" + VERSION + " with ❤️ by 0xDA_bit",
        "code": "Código en GitHub",
        "skip": "Saltar al contenido",
        "nav_shortcuts": "Atajos", "nav_drag": "Arrastrar", "nav_sleep": "Reposo", "nav_install": "Instalar",
    },
    "en": {
        "lang": "en", "path": "../", "other_href": "../", "other_lang": "es", "other": "Español",
        "title": "toc: put your windows in place on macOS",
        "description": "toc is a macOS menu bar app that moves the active window to halves, thirds or quarters "
                       "of the screen with a shortcut or by dragging it to an edge.",
        "h1": "Every window, in its place.",
        "lede": "toc lives in your Mac's menu bar and moves the active window to halves, thirds or quarters "
                "of the screen with a keyboard shortcut, or when you drag it to an edge.",
        "download": "Download toc", "build": "Build from source",
        "requirements": "For macOS 26 or later, on Intel and Apple silicon Macs. Version " + VERSION + ".",
        "demo_label": "toc demo",
        "demo_hint": "Press ⌃⌥ and an arrow to try it here. With toc running, you'll move your real window.",
        "demo_window": "Notes",
        "demo_ready": "Ready to try",
        "demo_restore_empty": "There is no previous position",
        "shortcuts_h2": "Twenty positions, each with its shortcut",
        "shortcuts_p": "They are the same shortcuts Rectangle uses, so there is nothing new to learn. "
                       "In toc's menu every action has an icon that shows where the window will go.",
        "shortcuts_none": "no shortcut",
        "drag_h2": "Drag it to the edge",
        "drag_p": "Take a window to the edge of the screen and toc shows you where it will land. "
                  "Let go and it snaps into place.",
        "drag_left": "Side edges", "drag_left_d": "left or right half",
        "drag_top": "Top edge", "drag_top_d": "maximize",
        "drag_corner": "Corners", "drag_corner_d": "a quarter of the screen",
        "drag_note": "When you resize a window from its edge, toc stays out of the way.",
        "drag_svg_top": "maximize", "drag_svg_side": "half", "drag_svg_corner": "quarter",
        "sleep_h2": "It doesn't go quiet after sleep",
        "sleep_p": "On some Macs running macOS 26, after waking from sleep, macOS stops giving Accessibility apps "
                   "access to windows. Window managers stop responding without saying why, and only a restart "
                   "fixes it. toc was built to speak up when that happens.",
        "sleep_steps": [
            "Your Mac wakes up and, three seconds later, toc checks that Accessibility responds.",
            "If macOS returns the app instead of its windows, toc's icon changes to ⚠︎ and explains what happened.",
            "Finder, Safari, System Settings and other scriptable apps keep moving through Apple Events.",
            "For everything else, toc tells you how to recover: restart your Mac, because logging out is not enough.",
        ],
        "sleep_diag": "If you want to dig in, “Copy diagnostics” in toc's menu gives you a report of what macOS sees.",
        "install_h2": "Install toc",
        "dl_h3": "Download",
        "dl_p": "Published versions are on the repository's releases page on GitHub.",
        "dl_button": "See releases on GitHub",
        "dl_note": "toc is signed with its own certificate, not one from Apple. The first time you open it, macOS "
                   "will block it: go to System Settings → Privacy & Security and click “Open Anyway”.",
        "src_h3": "Build from source",
        "src_p": "You need macOS 26 and Xcode 26. The script builds a universal binary, signs it and copies it to Applications.",
        "src_steps": ["Clone the repository:", "Go into the folder:", "Build and install:", "Open toc:"],
        "after_h3": "After installing",
        "after_p": "Give toc the Accessibility permission when it asks. To open it when your Mac starts, "
                   "check “Open at login” in its menu.",
        "footer_meta": "toc v" + VERSION + " with ❤️ by 0xDA_bit",
        "code": "Code on GitHub",
        "skip": "Skip to content",
        "nav_shortcuts": "Shortcuts", "nav_drag": "Drag", "nav_sleep": "Sleep", "nav_install": "Install",
    },
}

COMMANDS = [
    f"git clone {REPO}.git",
    "cd toc",
    "./scripts/build-app.sh --install",
    "open /Applications/toc.app",
]


## @brief  Compone la lista de atajos agrupada como el menú de toc.
#
#  @param[in]  t     Textos del idioma (dict).
#  @param[in]  lang  Código de idioma, "es" o "en" (str).
#  @return HTML de los grupos (str).
def shortcut_groups(t, lang):
    groups = {}
    for action, group, shortcut, es, en in ACTIONS:
        name = es if lang == "es" else en
        combo = keys(shortcut) if shortcut else f'<span class="none">{t["shortcuts_none"]}</span>'
        groups.setdefault(group, []).append(
            f'<li>{icon(action)}<span class="name">{html.escape(name)}</span>'
            f'<span class="combo">{combo}</span></li>')
    return "\n".join(f'<ul class="menu-group">{"".join(items)}</ul>' for items in groups.values())


## @brief  Compone los botones de prueba de la demo.
#
#  @param[in]  lang  Código de idioma (str).
#  @return HTML de los botones (str).
def demo_buttons(lang):
    out = []
    for action, _, shortcut, es, en in ACTIONS:
        if action in DEMO_KEYS:
            name = es if lang == "es" else en
            out.append(f'<button type="button" data-action="{action}" title="{html.escape(name)} ({shortcut})">'
                       f'{icon(action)}<span class="visually-hidden">{html.escape(name)}</span></button>')
    return "".join(out)


## @brief  Dibuja el plano de las zonas de arrastre.
#
#  @param[in]  t  Textos del idioma (dict).
#  @return Código SVG en línea (str).
def drag_blueprint(t):
    return f'''<svg class="blueprint" viewBox="0 0 480 312" role="img" aria-labelledby="bp-title">
  <title id="bp-title">{html.escape(t["drag_h2"])}</title>
  <rect class="bp-screen" x="20" y="20" width="440" height="260" rx="10"/>
  <rect class="bp-band" x="20" y="20" width="440" height="14"/>
  <rect class="bp-band" x="20" y="20" width="14" height="260"/>
  <rect class="bp-band" x="446" y="20" width="14" height="260"/>
  <rect class="bp-corner" x="20" y="20" width="56" height="56"/>
  <rect class="bp-corner" x="404" y="20" width="56" height="56"/>
  <rect class="bp-corner" x="20" y="224" width="56" height="56"/>
  <rect class="bp-corner" x="404" y="224" width="56" height="56"/>
  <text class="bp-label" x="240" y="56" text-anchor="middle">{html.escape(t["drag_svg_top"])}</text>
  <text class="bp-label" x="52" y="158" text-anchor="start">{html.escape(t["drag_svg_side"])}</text>
  <text class="bp-label" x="428" y="158" text-anchor="end">{html.escape(t["drag_svg_side"])}</text>
  <text class="bp-label bp-small" x="48" y="256" text-anchor="middle">{html.escape(t["drag_svg_corner"])}</text>
  <path class="bp-dim" d="M20 294h56M20 290v8M76 290v8"/>
  <text class="bp-dim-text" x="48" y="308" text-anchor="middle">40 pt</text>
</svg>'''


## @brief  Calcula una huella corta de un archivo, para invalidar la caché del navegador.
#
#  @param[in]  name  Ruta relativa a la raíz de la web (str).
#  @return Ocho primeros caracteres del hash MD5 del contenido (str).
def fingerprint(name):
    return hashlib.md5((ROOT / name).read_bytes()).hexdigest()[:8]


## @brief  Genera la página completa de un idioma.
#
#  @param[in]  lang  Código de idioma (str).
#  @return Documento HTML (str).
def page(lang):
    t = TEXT[lang]
    p = t["path"]
    labels = {a: (es if lang == "es" else en) for a, _, _, es, en in ACTIONS}
    labels["_ready"] = t["demo_ready"]
    labels["_empty"] = t["demo_restore_empty"]
    labels_init = html.escape(labels["rightHalf"])
    sleep_steps = "".join(f"<li>{html.escape(s)}</li>" for s in t["sleep_steps"])
    src_steps = "".join(f"<li>{html.escape(label)}<pre><code>{html.escape(cmd)}</code></pre></li>"
                        for label, cmd in zip(t["src_steps"], COMMANDS))
    alternate = "en/" if lang == "es" else ""
    return f'''<!doctype html>
<!--
-------------------------------------------------------------------------------
Name:     {"index.html" if lang == "es" else "en/index.html"}
Purpose:  Web de presentación de toc ({"castellano" if lang == "es" else "inglés"}). Generada por
          tools/build.py: no se edita a mano.
Version:  v0.0.1
Author:   David Alvarez Medina aka 0xDA_bit
Created:  20/11/2026
-------------------------------------------------------------------------------
-->
<html lang="{t["lang"]}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(t["title"])}</title>
<meta name="description" content="{html.escape(t["description"])}">
<meta name="color-scheme" content="light dark">
<meta name="theme-color" content="#1e4a57">
<link rel="alternate" hreflang="es" href="https://oxdabit.github.io/toc/">
<link rel="alternate" hreflang="en" href="https://oxdabit.github.io/toc/en/">
<link rel="icon" href="{p}assets/toc.svg" type="image/svg+xml">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Epilogue:wght@400;500;700;800&family=Sometype+Mono:wght@500&display=swap">
<link rel="stylesheet" href="{p}assets/style.css?v={fingerprint("assets/style.css")}">
<script defer src="{p}assets/demo.js?v={fingerprint("assets/demo.js")}"></script>
</head>
<body>
<a class="skip" href="#contenido">{t["skip"]}</a>

<header class="hero">
  <div class="hero-tiles" aria-hidden="true"><i></i><i></i><i></i></div>
  <nav class="top" aria-label="toc">
    <a class="wordmark" href="{p if p else "./"}"><img src="{p}assets/toc.svg" alt="" width="36" height="36">toc</a>
    <ul>
      <li><a href="#atajos">{t["nav_shortcuts"]}</a></li>
      <li><a href="#arrastrar">{t["nav_drag"]}</a></li>
      <li><a href="#reposo">{t["nav_sleep"]}</a></li>
      <li><a href="#instalar">{t["nav_install"]}</a></li>
      <li><a href="{p}{alternate}" hreflang="{t["other_lang"]}" lang="{t["other_lang"]}">{t["other"]}</a></li>
    </ul>
  </nav>

  <div class="hero-grid">
    <div class="hero-copy">
      <h1>{html.escape(t["h1"])}</h1>
      <p class="lede">{html.escape(t["lede"])}</p>
      <p class="actions">
        <a class="button primary" href="{REPO}/releases">{t["download"]}</a>
        <a class="button ghost" href="#compilar">{t["build"]}</a>
      </p>
      <p class="requirements">{html.escape(t["requirements"])}</p>
    </div>

    <figure class="shortcut-demo" data-demo aria-label="{t["demo_label"]}">
      <div class="sd-screen" aria-hidden="true">
        <div class="sd-ghost"></div>
        <div class="sd-zone"></div>
      </div>
      <div class="sd-keys" aria-hidden="true">
        <kbd class="sd-mod">⌃</kbd><span class="sd-plus">+</span><kbd class="sd-mod">⌥</kbd><span class="sd-plus">+</span><kbd class="sd-key">→</kbd>
      </div>
      <figcaption>
        <p class="sd-label" aria-live="polite">{labels_init}</p>
        <p class="sd-hint">{html.escape(t["demo_hint"])}</p>
      </figcaption>
      <script type="application/json" class="demo-labels">{json.dumps(labels, ensure_ascii=False)}</script>
    </figure>
  </div>
</header>

<main id="contenido">
  <section id="atajos" class="section">
    <div class="section-head">
      <h2>{t["shortcuts_h2"]}</h2>
      <p>{html.escape(t["shortcuts_p"])}</p>
    </div>
    <div class="menu">{shortcut_groups(t, lang)}</div>
  </section>

  <section id="arrastrar" class="section split">
    <div class="section-head">
      <h2>{t["drag_h2"]}</h2>
      <p>{html.escape(t["drag_p"])}</p>
      <dl class="zones">
        <div><dt>{t["drag_left"]}</dt><dd>{t["drag_left_d"]}</dd></div>
        <div><dt>{t["drag_top"]}</dt><dd>{t["drag_top_d"]}</dd></div>
        <div><dt>{t["drag_corner"]}</dt><dd>{t["drag_corner_d"]}</dd></div>
      </dl>
      <p class="note">{html.escape(t["drag_note"])}</p>
    </div>
    {drag_blueprint(t)}
  </section>

  <section id="reposo" class="section sleep">
    <div class="section-head">
      <h2>{t["sleep_h2"]}</h2>
      <p>{html.escape(t["sleep_p"])}</p>
    </div>
    <ol class="steps">{sleep_steps}</ol>
    <p class="note">{html.escape(t["sleep_diag"])}</p>
  </section>

  <section id="instalar" class="section">
    <h2>{t["install_h2"]}</h2>
    <div class="install">
      <div>
        <h3>{t["dl_h3"]}</h3>
        <p>{html.escape(t["dl_p"])}</p>
        <p><a class="button primary" href="{REPO}/releases">{t["dl_button"]}</a></p>
        <p class="note">{html.escape(t["dl_note"])}</p>
      </div>
      <div id="compilar">
        <h3>{t["src_h3"]}</h3>
        <p>{html.escape(t["src_p"])}</p>
        <ol class="commands">{src_steps}</ol>
      </div>
    </div>
    <div class="after">
      <h3>{t["after_h3"]}</h3>
      <p>{html.escape(t["after_p"])}</p>
    </div>
  </section>
</main>

<footer class="footer">
  <p class="meta">{html.escape(t["footer_meta"])}<br><a href="{REPO}">{t["code"]}</a></p>
  <a class="brand-mark" href="https://oxdabit.com"><img src="{p}assets/oxdabit.svg" alt="Isotipo de 0xDA bit" width="56" height="56"></a>
  <p class="brand"><b>0xDA</b> bit · <i>Del boceto al plato</i></p>
  <p class="links"><a href="https://oxdabit.com">oxdabit.com</a> · <a href="https://www.youtube.com/@0xDAbitLabs">YouTube</a> · <a href="https://github.com/OxDAbit">GitHub</a> · <a href="https://x.com/0xDA_bit">X</a> · <a href="https://www.instagram.com/oxdabitlabs/">Instagram</a></p>
</footer>
</body>
</html>
'''


## @brief  Escribe las dos versiones de la página.
def main():
    (ROOT / "index.html").write_text(page("es"), encoding="utf-8")
    (ROOT / "en").mkdir(exist_ok=True)
    (ROOT / "en" / "index.html").write_text(page("en"), encoding="utf-8")
    print("index.html y en/index.html generados")


if __name__ == "__main__":
    main()
