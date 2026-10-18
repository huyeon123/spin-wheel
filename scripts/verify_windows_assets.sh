#!/usr/bin/env bash
# Loads the embedded PCK with the host Godot engine; not Windows OS execution.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXE="${1:-$ROOT/build/windows/SpinWheel.exe}"
EXE="$(realpath "$EXE")"
GODOT="${GODOT:-godot}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/data" "$TMP/cache"
XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache" timeout 30 \
 "$GODOT" --headless --main-pack "$EXE" --script "$ROOT/tests/test_exported_startup.gd" 2>&1 | tee "$TMP/output.log"
grep -q 'EXPORTED_STARTUP_OK:' "$TMP/output.log"
if grep -Eq 'SCRIPT ERROR:|^ERROR:' "$TMP/output.log"; then
 echo 'Exported startup emitted errors' >&2; exit 1
fi
