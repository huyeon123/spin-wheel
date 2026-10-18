#!/usr/bin/env bash
# Validates the actual exported scene and bytecode, not Android's GPU/OS runtime.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APK="${1:-$ROOT/build/android/SpinWheel-debug.apk}"
GODOT="${GODOT:-godot}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q "$APK" 'assets/*' -d "$TMP"
# Godot Android's command-line asset is a count followed by length-prefixed UTF-8 strings.
# Verify exported flags rather than only trusting source export_presets.cfg.
python3 - "$TMP/assets/_cl_" <<'PYFLAGS'
import struct, sys
from pathlib import Path
payload = Path(sys.argv[1]).read_bytes()
offset = 0
def read_u32():
    global offset
    if offset + 4 > len(payload):
        raise SystemExit("Malformed Android command-line asset")
    value = struct.unpack_from("<I", payload, offset)[0]
    offset += 4
    return value
args = []
for _ in range(read_u32()):
    length = read_u32()
    if offset + length > len(payload):
        raise SystemExit("Truncated Android command-line argument")
    args.append(payload[offset:offset + length].decode("utf-8").rstrip("\0"))
    offset += length
if offset != len(payload):
    raise SystemExit("Unexpected trailing Android command-line bytes")
for flag in ("--fullscreen", "--edge_to_edge"):
    if flag not in args:
        raise SystemExit("Missing exported Android flag: " + flag)
print("ANDROID_FULLSCREEN_FLAGS_OK: immersive + edge-to-edge")
PYFLAGS
mkdir -p "$TMP/data" "$TMP/cache"
XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache" timeout 30 \
 "$GODOT" --headless --path "$TMP/assets" --script "$ROOT/tests/test_exported_startup.gd" 2>&1 | tee "$TMP/output.log"
grep -q 'EXPORTED_STARTUP_OK:' "$TMP/output.log"
if grep -Eq 'SCRIPT ERROR:|^ERROR:' "$TMP/output.log"; then
 echo 'Exported startup emitted errors' >&2; exit 1
fi
