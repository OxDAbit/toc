#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# Name:     scripts/package-release.sh
# Purpose:  Empaqueta toc para publicar una versión en GitHub. Compila con
#           build-app.sh, copia toc.app a una carpeta temporal fuera de iCloud,
#           quita los atributos extendidos, verifica la firma, genera
#           dist/toc-X.Y.Z.zip, comprueba que la firma sigue siendo válida al
#           descomprimirlo y guarda su suma SHA-256 en dist/toc-X.Y.Z.zip.sha256.
#           No crea la etiqueta ni publica nada: muestra la orden para hacerlo.
# Version:  v0.0.1
# Author:   David Alvarez Medina aka 0xDA_bit
# Created:  20/11/2026
# -------------------------------------------------------------------------------

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/toc.app"
DIST="$ROOT/dist"
WORK="$(mktemp -d)"
SKIP_BUILD=false
trap 'rm -rf "$WORK"' EXIT

## @brief  Interpreta los argumentos del script.
#
#  @param[in]  $@  Argumentos recibidos (solo se admite --skip-build).
parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --skip-build) SKIP_BUILD=true ;;
            -h|--help)
                echo "Uso: $0 [--skip-build]"
                echo "  --skip-build  Empaqueta build/toc.app tal como está, sin recompilar."
                exit 0 ;;
            *) echo "Opción desconocida: $arg" >&2; exit 1 ;;
        esac
    done
}

## @brief  Lee la versión de toc del Info.plist.
#
#  @return Escribe la versión (por ejemplo, 0.0.2) en la salida estándar.
read_version() {
    /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT/Resources/Info.plist"
}

## @brief  Avisa si hay cambios sin commit, porque el zip no correspondería a ningún commit.
check_worktree() {
    if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
        echo "⚠ Hay cambios sin commit: el zip no corresponderá exactamente a ningún commit."
    fi
}

## @brief  Copia toc.app a la carpeta temporal sin atributos y verifica su firma.
#
#  @return Deja la copia limpia en $WORK/stage/toc.app.
stage_app() {
    echo "→ Preparando una copia limpia de toc.app…"
    mkdir -p "$WORK/stage"
    ditto --noextattr --noqtn "$APP" "$WORK/stage/toc.app"
    # iCloud puede volver a añadir com.apple.FinderInfo, que rompe la firma estricta.
    xattr -cr "$WORK/stage/toc.app"
    codesign --verify --strict "$WORK/stage/toc.app"
}

## @brief  Comprime la copia limpia en dist/ y comprueba la firma tras descomprimirla.
#
#  @param[in]  $1  Ruta del zip de destino.
make_zip() {
    local zip="$1"
    echo "→ Comprimiendo $(basename "$zip")…"
    mkdir -p "$DIST"
    rm -f "$zip" "$zip.sha256"
    (cd "$WORK/stage" && ditto -c -k --norsrc --noextattr --keepParent toc.app "$zip")
    mkdir -p "$WORK/check"
    ditto -x -k "$zip" "$WORK/check"
    codesign --verify --strict "$WORK/check/toc.app"
    lipo -info "$WORK/check/toc.app/Contents/MacOS/toc"
}

## @brief  Calcula la suma SHA-256 del zip y la guarda junto a él.
#
#  @param[in]  $1  Ruta del zip.
write_checksum() {
    local zip="$1"
    (cd "$(dirname "$zip")" && shasum -a 256 "$(basename "$zip")" > "$(basename "$zip").sha256")
    cat "$zip.sha256"
}

parse_args "$@"
VERSION="$(read_version)"
ZIP="$DIST/toc-$VERSION.zip"
check_worktree
if [[ "$SKIP_BUILD" == false ]]; then
    "$ROOT/scripts/build-app.sh"
fi
stage_app
make_zip "$ZIP"
write_checksum "$ZIP"

echo "✓ Listo: $ZIP"
echo
echo "Para publicarla (crea la etiqueta v$VERSION en el commit actual):"
echo "  gh release create v$VERSION \"$ZIP\" --title \"toc v$VERSION\" --notes-file <notas.md>"
