<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-silueta-oscuro.svg">
    <img src="assets/logo-silueta-claro.svg" alt="Logo de toc" width="128" height="128">
  </picture>
</p>

<h1 align="center">toc</h1>

<p align="center">
  Cada ventana, en su sitio: coloca tus ventanas en macOS con atajos o arrastrándolas a los bordes<br>
  <sub>by <a href="https://oxdabit.com"><img src="assets/oxdabit.png" alt="" width="16" height="16"> <b>0xDA</b> bit</a></sub>
</p>

<p align="center">
  <img alt="Versión 0.0.2" src="https://img.shields.io/badge/versi%C3%B3n-0.0.2-f3e5ab?style=flat-square&labelColor=1c3f6e">
  <img alt="macOS 26" src="https://img.shields.io/badge/macOS-26-f3e5ab?style=flat-square&labelColor=1c3f6e&logo=apple&logoColor=efebe4">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-f3e5ab?style=flat-square&labelColor=1c3f6e&logo=swift&logoColor=efebe4">
  <img alt="Licencia MIT" src="https://img.shields.io/badge/licencia-MIT-f3e5ab?style=flat-square&labelColor=1c3f6e">
</p>

<p align="center">
  <a href="https://oxdabit.com/toc/"><b>oxdabit.com/toc</b></a>
</p>

toc vive en la barra de menús de tu Mac y coloca la ventana activa en mitades, tercios o cuartos de la pantalla con un atajo de teclado, o arrastrándola hasta un borde. Funciona en macOS 26 o posterior, en Mac con Intel o Apple Silicon.

## Veinte posiciones, cada una con su atajo

Son los mismos atajos que usa Rectangle, así que no tienes que aprender nada nuevo. En el menú de toc cada acción lleva un icono que muestra dónde quedará la ventana.

| Mitades | Atajo | Cuartos | Atajo |
|---|---|---|---|
| Mitad izquierda | `⌃⌥←` | Arriba a la izquierda | `⌃⌥U` |
| Mitad derecha | `⌃⌥→` | Arriba a la derecha | `⌃⌥I` |
| Mitad central | sin atajo | Abajo a la izquierda | `⌃⌥J` |
| Mitad superior | `⌃⌥↑` | Abajo a la derecha | `⌃⌥K` |
| Mitad inferior | `⌃⌥↓` | | |

| Tercios | Atajo | Tamaño | Atajo |
|---|---|---|---|
| Primer tercio | `⌃⌥D` | Maximizar | `⌃⌥↩` |
| Tercio central | `⌃⌥F` | Casi maximizar | sin atajo |
| Último tercio | `⌃⌥G` | Maximizar altura | `⌃⌥⇧↑` |
| Primeros dos tercios | `⌃⌥E` | Centrar | `⌃⌥C` |
| Dos tercios centrales | sin atajo | Restaurar | `⌃⌥⌫` |
| Últimos dos tercios | `⌃⌥T` | | |

## Arrastra hasta el borde

Lleva una ventana hasta el borde de la pantalla y toc te enseña dónde va a quedar. Suéltala y se coloca sola.

| Llevas el cursor a… | La ventana queda en… |
|---|---|
| Bordes laterales | Mitad izquierda o derecha |
| Borde superior | Maximizada |
| Esquinas (40 pt) | Un cuarto de pantalla |

Si estás cambiando el tamaño de una ventana desde su borde, toc no interviene. Puedes desactivar el arrastre en el menú de toc, con «Ajustar al arrastrar a los bordes».

## No se queda callada después del reposo

En algunos Mac con macOS 26, al salir del reposo, macOS deja de dar acceso a las ventanas a las apps de Accesibilidad. Los gestores de ventanas dejan de responder sin explicar por qué, y solo se arregla reiniciando. toc nació para no quedarse callada cuando pasa.

- El Mac despierta y, a los tres segundos, toc comprueba que Accesibilidad responde.
- Si macOS devuelve la app en lugar de sus ventanas, el icono de toc cambia a ⚠︎ y te explica qué ocurre.
- Finder, Safari, Ajustes del Sistema y las demás apps scriptables se siguen moviendo mediante Apple Events.
- Para el resto, toc te dice cómo recuperarlo: reiniciar el Mac, porque cerrar sesión no basta.

Si quieres investigarlo, «Copiar diagnóstico» en el menú de toc te da un informe con lo que ve macOS. Para un análisis más a fondo está [`toc-probe`](tools/toc-probe/README.md), la sonda de diagnóstico con la que se estudió el fallo.

## Instalar toc

### Descarga

Las versiones publicadas están en la [página de versiones](https://github.com/OxDAbit/toc/releases) del repositorio.

toc está firmada con un certificado propio, no con uno de Apple. La primera vez que la abras, macOS la bloqueará: ve a Ajustes del Sistema → Privacidad y seguridad y pulsa «Abrir igualmente».

### Compila desde el código

Necesitas macOS 26 y Xcode 26. El script compila un binario universal, lo firma y lo copia a Aplicaciones.

```bash
git clone https://github.com/OxDAbit/toc.git
cd toc
./scripts/build-app.sh --install
open /Applications/toc.app
```

El script firma con el certificado «toc Code Signing» si lo encuentra en tu llavero (o con el que indiques en `TOC_SIGN_IDENTITY`). Si no, usa una firma ad hoc: toc funciona igual, pero macOS te volverá a pedir el permiso de Accesibilidad cada vez que la recompiles.

### Después de instalar

Concede a toc el permiso de Accesibilidad cuando te lo pida. Para que se abra al encender el Mac, marca «Abrir al iniciar sesión» en su menú.

## Para desarrolladores

| Carpeta | Contenido |
|---|---|
| `Sources/TocCore` | Lógica pura, sin AppKit: posiciones, coordenadas, zonas de arrastre y detector del fallo de Accesibilidad. |
| `Sources/toc` | La app: Accesibilidad, Apple Events, atajos, arrastre, menú y ciclo de vida. |
| `Tests/TocCoreTests` | Tests de `TocCore`. Se ejecutan con `swift test`. |
| `tools/toc-probe` | Sonda de diagnóstico de Accesibilidad. |
| `scripts` | Compilación y firma (`build-app.sh`), empaquetado de versiones para GitHub (`package-release.sh`) y generación del icono (`make-icon.swift`). |
| `docs` | [Notas de desarrollo](docs/notas-desarrollo.md). |

Para publicar una versión, `./scripts/package-release.sh` compila toc, la comprime en `dist/toc-X.Y.Z.zip` desde una copia limpia (iCloud añade atributos que rompen la firma), comprueba la firma tras descomprimirla y guarda la suma SHA-256. No publica nada: al terminar muestra la orden `gh release create` para hacerlo.

## Licencia

El código está bajo licencia [MIT](LICENSE): puedes usarlo, modificarlo y redistribuirlo manteniendo el aviso de copyright.

Quedan fuera de esa licencia el nombre e isotipo de **0xDA** bit y el nombre, logo e iconos de toc (`assets/oxdabit.png`, `assets/logo.svg`, `assets/logo-mono.svg`, `assets/logo-silueta-claro.svg`, `assets/logo-silueta-oscuro.svg`, `assets/icon.png` y `Resources/toc.icns`). Si publicas una versión modificada, usa tu propio nombre y tus propios gráficos.

---

<p align="center">
  <a href="https://oxdabit.com"><img src="assets/oxdabit.png" alt="Isotipo de 0xDA bit" width="56" height="56"></a>
</p>

<p align="center">
  <b>0xDA</b> bit · <i>Del boceto al plato</i><br>
  <sub><a href="https://oxdabit.com">oxdabit.com</a> · <a href="https://www.youtube.com/@0xDAbitLabs">YouTube</a> · <a href="https://github.com/OxDAbit">GitHub</a> · <a href="https://x.com/0xDA_bit">X</a> · <a href="https://www.instagram.com/oxdabitlabs/">Instagram</a></sub>
</p>
