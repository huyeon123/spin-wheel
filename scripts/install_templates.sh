#!/usr/bin/env bash
set -euo pipefail
VERSION=4.6.3
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${VERSION}.stable"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT
curl --fail --location --retry 3 "https://github.com/godotengine/godot-builds/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_export_templates.tpz" -o "$TEMP/templates.tpz"
mkdir -p "$DEST"
unzip -j -o "$TEMP/templates.tpz" 'templates/windows_release_x86_64.exe' 'templates/windows_debug_x86_64.exe' 'templates/android_debug.apk' 'templates/android_release.apk' 'templates/version.txt' -d "$DEST"
printf 'Installed Godot %s Windows and Android templates in %s\n' "$VERSION" "$DEST"
