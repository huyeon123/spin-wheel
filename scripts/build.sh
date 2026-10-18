#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
TARGET="${1:-all}"
if [[ "$TARGET" != windows && "$TARGET" != android && "$TARGET" != all ]]; then
  echo "Usage: $0 [all|windows|android]" >&2; exit 2
fi
mkdir -p build/windows build/android
export XDG_CACHE_HOME="${GODOT_BUILD_CACHE_HOME:-$PWD/build/cache}"
mkdir -p "$XDG_CACHE_HOME"
if [[ "$TARGET" == android || "$TARGET" == all ]]; then
  : "${ANDROID_HOME:?Set ANDROID_HOME to your Android SDK directory}"
  : "${JAVA_HOME:?Set JAVA_HOME to your JDK 17 or newer directory}"
  # Isolate generated editor settings; never overwrite the developer's settings.
  export XDG_CONFIG_HOME="${GODOT_BUILD_CONFIG_HOME:-$PWD/build/editor-config}"
  mkdir -p "$XDG_CONFIG_HOME/godot"
  cat > "$XDG_CONFIG_HOME/godot/editor_settings-4.6.tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
SETTINGS
fi
"$GODOT" --headless --path . --editor --import
if [[ "$TARGET" == windows || "$TARGET" == all ]]; then
  "$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/SpinWheel.exe
  test -s build/windows/SpinWheel.exe
fi
if [[ "$TARGET" == android || "$TARGET" == all ]]; then
  "$GODOT" --headless --path . --export-debug "Android" build/android/SpinWheel-debug.apk
  test -s build/android/SpinWheel-debug.apk
fi
