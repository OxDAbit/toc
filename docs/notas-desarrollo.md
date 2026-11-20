# Notas de desarrollo de toc

Resumen de las decisiones tomadas al crear toc (20/11/2026), para retomar el
proyecto sin tener que reconstruir el contexto.

## Por qué existe toc

En un Mac Intel con macOS 26.7.1 (monitor C34H89x con la tapa cerrada, que
despierta por USB-C), Rectangle dejaba de mover ventanas tras el reposo y solo
volvía a funcionar reiniciando el Mac. El diagnóstico con `tools/toc-probe`
demostró que el fallo es de macOS, no de Rectangle:

- Tras el reposo, la lista de ventanas de Accesibilidad (`kAXWindowsAttribute`)
  devuelve elementos con rol `AXApplication` (la propia app) en lugar de
  `AXWindow`, en **todas** las apps, incluidas las abiertas después.
- Las vías alternativas de Accesibilidad también fallan: tokens remotos
  (`_AXUIElementCreateWithRemoteToken`) y hit-test
  (`AXUIElementCopyElementAtPosition`).
- WindowServer sigue viendo las ventanas correctamente (`CGWindowList`).
- **Apple Events sí mueve ventanas**, pero solo en apps scriptables (Finder,
  Safari, Ajustes del Sistema…), no en apps de Electron (Teams, Claude, Warp…).

| Prueba | ¿Lo arregla? |
|---|---|
| Reiniciar o actualizar Rectangle | No |
| Renovar el permiso de Accesibilidad | No |
| Cerrar sesión | No |
| Reiniciar WindowServer (`sudo killall -9 WindowServer`) | No |
| Reiniciar `com.apple.hiservices-xpcservice` | No |
| Reiniciar el Mac | **Sí** |

Descartados también: la Entrada Segura del teclado (Secure Input) y la versión
de Rectangle. El fallo vive en el núcleo o en un servicio de sistema que solo se
reinicia con el Mac. Conviene avisar a Apple con los informes de la sonda.

## Arquitectura de la app

- **Swift 6 + AppKit**, app de barra de menús (`LSUIElement`), macOS 26.0 como
  mínimo, binario universal (x86_64 + arm64).
- **Paquete de Swift** (`Package.swift`) en lugar de proyecto de Xcode;
  `scripts/build-app.sh` monta, firma y, con `--install`, copia a
  `/Applications/toc.app`.
- **Firma** con el certificado autofirmado «toc Code Signing» del Llavero, para
  que macOS conserve el permiso de Accesibilidad entre compilaciones. La firma
  se hace en una carpeta temporal porque iCloud añade atributos que `codesign`
  rechaza.
- **TocCore** (con tests): `LayoutEngine` (posiciones), `ScreenGeometry`
  (coordenadas), `SnapArea` (zonas de arrastre) y `AXHealthDetector` (detector
  del fallo).
- **Estrategia frente al fallo**:
  1. Vía principal: Accesibilidad, pidiendo los elementos de nuevo en cada acción
     y comprobando que la ventana se ha movido.
  2. Detector: si WindowServer ve ventanas y AX devuelve rol `AXApplication`,
     macOS está en el estado roto (icono ⚠︎ y aviso).
  3. Plan B: Apple Events para las apps scriptables.
  4. Para el resto, toc explica que hay que reiniciar el Mac.
- **Atajos** con Carbon (`RegisterEventHotKey`), que funcionan con la Entrada
  Segura activa y se vuelven a registrar al despertar.
- **Arrastre a los bordes** detectado con WindowServer, no con Accesibilidad.
- **Logo**: monograma (la «o» como ventana con la mitad rellena). Todo sale de
  `scripts/make-icon.swift`.

## Web de presentación (rama `gh-pages`)

- Publicada en https://oxdabit.github.io/toc/ (GitHub Pages desde `gh-pages`,
  carpeta raíz).
- HTML estático en castellano (`/`) e inglés (`/en/`), generado por
  `tools/build.py`: los textos se editan ahí y se ejecuta
  `python3 tools/build.py`. No se editan los HTML a mano.
- Para trabajar en ella: `git switch gh-pages`.
- Identidad visual:
  - Paleta de 0xDA bit (blanco roto `#efebe4`, vainilla `#f3e5ab`) con el
    **azul petróleo `#1e4a57`** como color propio de toc (portada, títulos y
    acentos).
  - Tipografía Epilogue, y Sometype Mono solo para las teclas.
  - **No** usar el fondo de cuadrícula de plano técnico: es el de oxdabit.com.
  - Portada en mosaico: cada panel es el contenedor real de su contenido.
  - La animación de la portada muestra un atajo (⌃⌥ + tecla) y la ventana
    colocándose.
  - Pie: «toc vX.Y.Z with ❤️ by 0xDA_bit» y, debajo, el enlace al código.

## Pendiente

- Licencia del proyecto (necesaria para la insignia del README).
- README con la cabecera y el pie de 0xDA bit.
- Subir la versión a 0.0.2 cuando toque.
- Preferencias (cambiar atajos, elegir acciones del menú) y mover ventanas entre
  pantallas.
- Publicar una versión en GitHub Releases (el botón «Descargar» de la web
  apunta ahí).
- Enviar el informe del fallo a Apple (Asistente de Comentarios), usando
  `toc-probe --redact` para ocultar los títulos de las ventanas.
