#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# Name:     scripts/build-app.sh
# Purpose:  Compila toc como binario universal (Intel y Apple Silicon), monta
#           build/toc.app con su Info.plist y lo firma con el certificado
#           autofirmado «toc Code Signing» (o el que indique TOC_SIGN_IDENTITY),
#           para que macOS conserve el permiso de Accesibilidad entre versiones.
#           Con --install, además la copia a /Applications/toc.app.
# Version:  v0.0.1
# Author:   David Alvarez Medina aka 0xDA_bit
# Created:  20/11/2026
# -------------------------------------------------------------------------------

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IDENTITY="${TOC_SIGN_IDENTITY:-toc Code Signing}"
BUNDLE_ID="com.oxdabit.toc"
APP="$ROOT/build/toc.app"
# La carpeta Documents puede estar sincronizada con iCloud, que añade atributos
# extendidos que codesign rechaza: se monta y firma fuera y luego se copia.
STAGE="$(mktemp -d)/toc.app"
SWIFT_FLAGS=(-c release --arch arm64 --arch x86_64 --package-path "$ROOT")
INSTALL=false

## @brief  Interpreta los argumentos del script.
#
#  @param[in]  $@  Argumentos recibidos (solo se admite --install).
parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --install) INSTALL=true ;;
            -h|--help) echo "Uso: $0 [--install]"; exit 0 ;;
            *) echo "Opción desconocida: $arg" >&2; exit 1 ;;
        esac
    done
}

## @brief  Compila el ejecutable toc como binario universal.
#
#  @return Deja en BIN_DIR la carpeta con el ejecutable compilado.
build_binary() {
    echo "→ Compilando binario universal…"
    swift build "${SWIFT_FLAGS[@]}" --product toc
    BIN_DIR="$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)"
}

## @brief  Monta la estructura de toc.app en la carpeta temporal.
assemble_bundle() {
    echo "→ Montando toc.app…"
    mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"
    cp "$BIN_DIR/toc" "$STAGE/Contents/MacOS/toc"
    cp "$ROOT/Resources/Info.plist" "$STAGE/Contents/Info.plist"
    cp "$ROOT/Resources/toc.icns" "$STAGE/Contents/Resources/toc.icns"
    plutil -lint "$STAGE/Contents/Info.plist" >/dev/null
    xattr -cr "$STAGE"
}

## @brief  Firma toc.app y comprueba la firma.
#
#  Si el certificado no existe, avisa y deja la app con firma ad hoc: funciona,
#  pero macOS volverá a pedir el permiso de Accesibilidad en cada compilación.
sign_bundle() {
    if security find-identity -p codesigning | grep -q "${IDENTITY}"; then
        echo "→ Firmando con «${IDENTITY}»…"
        codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" --timestamp=none "$STAGE"
    else
        echo "⚠ No se encuentra el certificado «${IDENTITY}»: firma ad hoc."
        codesign --force --sign - --identifier "$BUNDLE_ID" "$STAGE"
    fi
    codesign --verify --strict --verbose=1 "$STAGE"
    lipo -info "$STAGE/Contents/MacOS/toc"
}

## @brief  Copia la app firmada a build/toc.app.
install_bundle() {
    rm -rf "$APP"
    mkdir -p "$(dirname "$APP")"
    ditto "$STAGE" "$APP"
    rm -rf "$(dirname "$STAGE")"
}

## @brief  Copia toc.app a /Applications, cerrando antes la copia en ejecución.
install_applications() {
    local dest="/Applications/toc.app"
    if pgrep -x toc >/dev/null; then
        echo "→ Cerrando toc…"
        osascript -e 'tell application id "com.oxdabit.toc" to quit' >/dev/null 2>&1 || true
        sleep 1
    fi
    rm -rf "$dest"
    ditto "$APP" "$dest"
    echo "✓ Instalado en $dest"
}

parse_args "$@"
build_binary
assemble_bundle
sign_bundle
install_bundle
echo "✓ Listo: $APP"
if [[ "$INSTALL" == true ]]; then
    install_applications
fi
