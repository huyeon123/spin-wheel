#!/usr/bin/env bash
# Validates the actual exported scene and bytecode, not Android's GPU/OS runtime.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APK="${1:-$ROOT/build/android/SpinWheel-debug.apk}"
GODOT="${GODOT:-godot}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q "$APK" 'assets/*' -d "$TMP"
mkdir -p "$TMP/data" "$TMP/cache"
XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache" timeout 30 \
 "$GODOT" --headless --path "$TMP/assets" --script "$ROOT/tests/test_exported_startup.gd" 2>&1 | tee "$TMP/output.log"
grep -q 'EXPORTED_STARTUP_OK:' "$TMP/output.log"
if grep -Eq 'SCRIPT ERROR:|^ERROR:' "$TMP/output.log"; then
 echo 'Exported startup emitted errors' >&2; exit 1
fi
