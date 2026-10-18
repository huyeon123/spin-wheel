#!/usr/bin/env bash
# Separately signed TEST candidates; ordinary build.sh/CI stays official-engine.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$(command -v "${GODOT:-godot}")"
: "${CUSTOM_ENGINE_LIB:?Set the compiled custom ARM64 release .so path}"
: "${ANDROID_HOME:?Set Android SDK root}"
: "${JAVA_HOME:?Set JDK root}"
: "${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:?Set existing test keystore path}"
: "${GODOT_ANDROID_KEYSTORE_DEBUG_USER:?Set existing test signer alias}"
: "${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:?Set existing test signer password}"
EXPECTED_SIGNER_SHA256="${EXPECTED_SIGNER_SHA256:-a30740b4b2f32490fbbe6d081f3a85db84859271d191b933ec57599eb9d5e8f1}"
TOOLS="${ANDROID_BUILD_TOOLS:-$ANDROID_HOME/build-tools/35.0.1}"
STAGE="$(mktemp -d)"
trap 'rm -rf -- "$STAGE"' EXIT
tar -C "$ROOT" --exclude='./.godot' --exclude='./build' --exclude='./.git' -cf - . | tar -C "$STAGE" -xf -
cd "$STAGE"
mkdir -p build "$ROOT/build/android" "$ROOT/build/logs" build/config/godot build/cache
export XDG_CONFIG_HOME="$STAGE/build/config" XDG_CACHE_HOME="$STAGE/build/cache"
cat > "$XDG_CONFIG_HOME/godot/editor_settings-4.6.tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]
[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
SETTINGS
# Change only isolated export signing, leaving the production preset unchanged.
python3 - <<'PY'
from pathlib import Path
p = Path('export_presets.cfg')
s = p.read_text()
assert 'package/signed=true' in s
p.write_text(s.replace('package/signed=true', 'package/signed=false'))
PY
checked_run() {
  local name="$1"; shift
  "$@" 2>&1 | tee "$ROOT/build/logs/custom-$name.log"
  if grep -Eiq '(^|[[:space:]])(SCRIPT ERROR|ERROR):|Parse Error|Failed to load script|Failed loading resource|Resource file not found|Could not resolve script' "$ROOT/build/logs/custom-$name.log"; then
    echo "Custom candidate rejected: $name emitted errors" >&2; return 1
  fi
}
checked_run import "$GODOT" --headless --path . --editor --import
rm -rf .godot/exported
checked_run export "$GODOT" --headless --path . --export-release Android build/official-unsigned.apk
GODOT="$GODOT" ./scripts/verify_apk_assets.sh build/official-unsigned.apk
python3 ./scripts/package_custom_android.py --baseline build/official-unsigned.apk --engine "$CUSTOM_ENGINE_LIB" --output build/custom-unsigned.apk --zipalign "$TOOLS/zipalign" | tee "$ROOT/build/logs/custom-package.json"
for variant in official custom; do
  cp "build/$variant-unsigned.apk" "build/$variant-test.apk"
  "$TOOLS/apksigner" sign --ks "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" --ks-key-alias "$GODOT_ANDROID_KEYSTORE_DEBUG_USER" --ks-pass env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD "build/$variant-test.apk"
  "$TOOLS/apksigner" verify --verbose --print-certs "build/$variant-test.apk" | tee "build/$variant-cert.txt"
  grep -Fq "certificate SHA-256 digest: $EXPECTED_SIGNER_SHA256" "build/$variant-cert.txt" || { echo "Signing identity mismatch; refusing candidate" >&2; exit 1; }
  "$TOOLS/zipalign" -c -P 16 4 "build/$variant-test.apk"
  GODOT="$GODOT" ./scripts/verify_apk_assets.sh "build/$variant-test.apk"
done
cp build/official-unsigned.apk "$ROOT/build/android/SpinWheel-official-release-unsigned.apk"
cp build/official-test.apk "$ROOT/build/android/SpinWheel-official-release-test.apk"
cp build/custom-test.apk "$ROOT/build/android/SpinWheel-custom-test.apk"
