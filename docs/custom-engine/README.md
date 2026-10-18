# Optional lightweight Android test engine

This is a separately signed experimental Android candidate. Normal `scripts/build.sh` and GitHub Actions continue using official full-engine Godot templates. The custom engine has not been exercised on the user's Galaxy; passing exported-asset checks does not test its Android renderer or native runtime.

## Provenance and compilation

- Official Godot 4.6.3 source: https://github.com/godotengine/godot/archive/refs/tags/4.6.3-stable.tar.gz
- Source archive SHA-256: `fa22b5f974125057087c9ef725eae582dbc5e39385dc377e8d5dbc295b367e1c`
- Official Android NDK r29: https://dl.google.com/android/repository/android-ndk-r29-linux.zip
- NDK archive SHA-1 verified against official Android repository metadata: `87e2bb7e9be5d6a1c6cdf5ec40dd4e0c6d07c30b`
- Python SCons 4.11.1 (PyPI).
- Place the adjacent `custom.py` in the extracted Godot source root. Configure the Android SDK with NDK r29.
- Build: `ANDROID_HOME=/path/to/android-sdk python -m SCons platform=android target=template_release arch=arm64 swappy=yes -j3`
- Strip the resulting `libgodot_android.so` using NDK r29's `llvm-strip`.
- Verified input engine SHA-256: `1b092f0b6c9050fe1936dc604843b8ff407448932cee3480a23c6b2d793a0498`; size 37,301,552 bytes.

The configuration keeps GL Compatibility, 2D, complete GUI, GDScript, advanced text shaping, Korean font support, SVG/WebP and WAV audio. It disables 3D, physics/navigation, Vulkan and unused networking/codec modules. `swappy=yes` does not link Swappy in this GL-only build because Godot's Android build links it only with Vulkan. This distinction and runtime compatibility still need device verification.

Godot uses the MIT license. Keep `assets/GODOT-LICENSE.txt`, `assets/GODOT-COPYRIGHT.txt` and `assets/FONT-LICENSE.txt` with distribution. The custom build configuration is included; the large compiled engine and all signing keys are deliberately excluded from source control.

## Fresh candidate packaging

Set `GODOT`, `JAVA_HOME`, `ANDROID_HOME`, `CUSTOM_ENGINE_LIB` and the three `GODOT_ANDROID_KEYSTORE_DEBUG_PATH`, `GODOT_ANDROID_KEYSTORE_DEBUG_USER`, `GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD` environment variables to an existing authorized test signing identity. Do not generate or rotate a key for an update. Run:

```sh
./scripts/build_custom_android.sh
```

The script stages fresh current project source without `.godot`, `build` or `.git`, imports it, and exports an unsigned **release** APK using the matching official Godot template. It validates the exported startup scene and UI, replaces only `lib/arm64-v8a/libgodot_android.so`, proves all other ZIP payload entries identical, aligns native libraries to 16 KB, and signs both custom and official fallback APKs with the same supplied identity. It preserves library compression and `extractNativeLibs` as exported by the template. It never reads the old 0.2.5 experimental app payload. It also rejects a certificate that differs from this app's established public signer SHA-256 (`a30740b4b2f32490fbbe6d081f3a85db84859271d191b933ec57599eb9d5e8f1`); `EXPECTED_SIGNER_SHA256` is available only for an explicitly authorized different signing identity.

Outputs under `build/android/`:

- `SpinWheel-custom-test.apk`: lightweight test candidate.
- `SpinWheel-official-release-test.apk`: full-engine release fallback, same app payload and version.
- `SpinWheel-official-release-unsigned.apk`: unsigned current-payload comparison input; do not distribute as installable.

Packaging-only entry point: `python3 scripts/package_custom_android.py --baseline CURRENT_UNSIGNED_APK --engine CUSTOM_ARM64_SO --output NEW_UNSIGNED_APK --zipalign /path/to/zipalign`. It does not sign, and refuses to overwrite the baseline.

The two signed test candidates have the same package and version code, so install one at a time. Switching between these variants preserves update identity only when their certificate matches the installed app. Never uninstall solely to bypass an unexpected certificate mismatch.

## Required verification before distribution

Verify version/package/ABI, `apksigner verify --print-certs`, established signer continuity, `zipalign -c -P 16 4`, and both exact exported-startup checks. Compare final signed APK payload entries against the official fallback, excluding signing metadata; only the Godot engine may differ.

On Galaxy, test launch, Korean text/IME, editing, color picker, audio, spin animation, gestures, preset/history persistence, keyboard overlays, back navigation, pause/resume and in-place update. Measure storage in Android Settings. APK size plus uncompressed native-library bytes is only a storage model; it excludes ART optimization, metadata, cache and user data.
