# toc-probe

Sonda de diagnóstico de Accesibilidad para gestores de ventanas de macOS. Se usa
para averiguar **por qué** un gestor de ventanas (Rectangle, toc…) deja de mover
ventanas tras el reposo antes de diseñar la solución en toc.

Rectangle solo registra el resultado (`result: (0.0, 0.0)`). La sonda registra
además el **código de error** de cada llamada a la API de Accesibilidad, cuánto
tarda y lo que ve WindowServer de esas mismas ventanas, y termina con un
veredicto.

## Compilar

Requiere Xcode 26 o superior.

```bash
cd tools/toc-probe
swift build -c release
```

El ejecutable queda en `.build/release/toc-probe`.

## Permiso de Accesibilidad

macOS no concede el permiso a la sonda, sino a la **app desde la que la
ejecutas** (Terminal, Warp…). La sonda la muestra en «App responsable».

1. Ajustes del Sistema → Privacidad y seguridad → Accesibilidad.
2. Activa esa app (o ejecuta la sonda con `--prompt` para que macOS lo pida).
3. Cuando termines el diagnóstico, puedes volver a desactivarla.

## Uso

```text
toc-probe [--app <bundle-id>]... [--all] [--move] [--deep] [--applescript] [--redact] [--prompt]
```

| Opción | Qué hace |
|---|---|
| *(ninguna)* | Inspecciona las ventanas del Finder. Solo lee. |
| `--app <id>` | Inspecciona otra app, por ejemplo `--app com.apple.TextEdit`. Se puede repetir. |
| `--all` | Inspecciona todas las apps con ventanas en pantalla. |
| `--move` | Mueve 40 px una ventana de cada app y la devuelve a su sitio. |
| `--deep` | Prueba vías alternativas a la AX estándar: tokens remotos (`_AXUIElementCreateWithRemoteToken`) y hit-test (`AXUIElementCopyElementAtPosition`). |
| `--applescript` | Prueba a mover con Apple Events, sin Accesibilidad. Solo apps scriptables (Finder, Safari…); macOS pide el permiso de Automatización. |
| `--redact` | Oculta los títulos de las ventanas, que pueden contener datos personales. Úsalo antes de compartir un informe. |
| `--prompt` | Pide a macOS el permiso de Accesibilidad si falta. |

## Cuándo ejecutarla

Con al menos una ventana del Finder y otra de Safari abiertas:

```bash
.build/release/toc-probe --all --move --deep --applescript | tee ~/Desktop/toc-probe.txt
```

Ejecútala **mientras el fallo está activo** (antes de reiniciar) y otra vez
después de reiniciar, como referencia.

## Cómo leer el veredicto

| Veredicto | Significado |
|---|---|
| AX estándar funciona | La vía que usa Rectangle responde en todas las apps. |
| AX estándar roto en todas las apps | WindowServer ve ventanas pero la vía estándar no devuelve ninguna legible. |
| Árbol AX corrupto | La lista de ventanas devuelve la propia app (rol `AXApplication`) en lugar de sus ventanas. |
| Vía tokens remotos / hit-test / Apple Events | En cuántas apps esa vía alternativa consigue mover la ventana. Es la que toc podría usar como plan B. |

Códigos de error más habituales:

| Código | Nombre | Significado |
|---|---|---|
| -25211 | `apiDisabled` | Sin permiso de Accesibilidad. |
| -25205 | `attributeUnsupported` | El elemento no tiene ese atributo (por ejemplo, una app no tiene posición). |
| -25204 | `cannotComplete` | La app no responde o la mensajería de Accesibilidad falla. |
| -25202 | `invalidUIElement` | La ventana ya no existe. |
| -25212 | `noValue` | El atributo no tiene valor. |
