#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
GODOT="$(command -v "$GODOT")"
TARGET="${1:-all}"
if [[ "$TARGET" != windows && "$TARGET" != android && "$TARGET" != all ]]; then
  echo "Usage: $0 [all|windows|android]" >&2; exit 2
fi
STAGE="$(mktemp -d)"
trap 'rm -rf -- "$STAGE"' EXIT
# Never carry converted scenes or editor caches into a release. A failed old
# import can otherwise leave a cached binary scene with its script stripped.
tar -C "$ROOT" --exclude='./.godot' --exclude='./build' --exclude='./.git' -cf - . | tar -C "$STAGE" -xf -
cd "$STAGE"
mkdir -p build/windows build/android "$ROOT/build/windows" "$ROOT/build/android" "$ROOT/build/logs"
export XDG_CACHE_HOME="$STAGE/build/cache"
export XDG_CONFIG_HOME="$STAGE/build/editor-config"
mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME/godot"
if [[ "$TARGET" == android || "$TARGET" == all ]]; then
  : "${ANDROID_HOME:?Set ANDROID_HOME to your Android SDK directory}"
  : "${JAVA_HOME:?Set JAVA_HOME to your JDK 17 or newer directory}"
  cat > "$XDG_CONFIG_HOME/godot/editor_settings-4.6.tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
SETTINGS
fi
checked_run() {
  local name="$1"; shift
  "$@" 2>&1 | tee "$ROOT/build/logs/$name.log"
  if grep -Eiq 'SCRIPT ERROR:|ERROR:|Parse Error|Failed to load script|Failed loading resource|Resource file not found|Could not resolve script|WARNING:.*(script|resource|file).*(missing|not found|failed|cannot)|WARNING:.*(missing|not found|failed|cannot).*(script|resource|file)' "$ROOT/build/logs/$name.log"; then
    echo "Build rejected: $name reported script/resource errors" >&2; return 1
  fi
}
checked_run import "$GODOT" --headless --path . --editor --import
if [[ "$TARGET" == windows || "$TARGET" == all ]]; then
  rm -rf -- .godot/exported
  checked_run windows "$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/SpinWheel.exe
  test -s build/windows/SpinWheel.exe
  GODOT="$GODOT" ./scripts/verify_windows_assets.sh build/windows/SpinWheel.exe
  cp build/windows/SpinWheel.exe "$ROOT/build/windows/SpinWheel.exe"
fi
if [[ "$TARGET" == android || "$TARGET" == all ]]; then
  rm -rf -- .godot/exported
  checked_run android "$GODOT" --headless --path . --export-debug "Android" build/android/SpinWheel-debug.apk
  test -s build/android/SpinWheel-debug.apk
  GODOT="$GODOT" ./scripts/verify_apk_assets.sh build/android/SpinWheel-debug.apk
  cp build/android/SpinWheel-debug.apk "$ROOT/build/android/SpinWheel-debug.apk"
fi
