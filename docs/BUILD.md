# Native builds

Use **Godot 4.6.3 Standard (GDScript)**, not the .NET edition. Windows and Android use the same project and game logic.

## Prerequisites

- Godot 4.6.3 on your PATH (`godot`), or set `GODOT` to its full executable path.
- Matching export templates: install via Godot's Export Template Manager or run `./scripts/install_templates.sh` on Linux.
- For Android: JDK 17 recommended (newer supported), Android SDK platform-tools, build-tools 35.0.1 and Android platform 35. Set `JAVA_HOME` and `ANDROID_HOME`.
- Bash, curl and unzip for the helper scripts. On Windows, use Godot's Project → Export UI or a Bash shell.

```sh
./scripts/install_templates.sh
./scripts/build.sh windows
JAVA_HOME=/path/to/jdk ANDROID_HOME=/path/to/android-sdk ./scripts/build.sh android
```

Exports:

- `build/windows/SpinWheel.exe`: unsigned Windows x86_64 release executable, with game data embedded. No separate `.pck` is required. Windows may display an unsigned-app warning.
- `build/android/SpinWheel-debug.apk`: ARM64 Android test APK (Android 7/API 24 or newer; the Godot 4.6.3 template targets API 36). This is a development-signed build for sideload testing, not a Google Play release. No release keystore, credentials or store publishing is included.

The build script isolates generated editor settings in `build/editor-config`; it does not overwrite your editor preferences. Export templates must be installed in the standard Godot data directory (or under your `XDG_DATA_HOME`). Android uses Godot's prebuilt APK template, so this project does not require Gradle, NDK or CMake builds.

To build from the editor, choose the `Windows Desktop` or `Android` preset. Configure Android SDK and Java SDK paths in Editor Settings → Export → Android. Keep **Export With Debug enabled** for the Android test APK.

## CI

`.github/workflows/build.yml` runs resource import, headless tests, and both exports on GitHub Actions. It uploads downloadable native build artifacts; it does not publish a release or upload to any app store. The workflow runs only after this source is pushed to a GitHub repository. Review GitHub Actions usage limits before enabling it on a private repository.

## Release considerations

The Android package ID is `io.github.huyeon123.spinwheel`. Keep this ID stable after distributing signed builds. A production Android build needs your own securely managed release signing key, a chosen package identity, version management, and store compliance review. Windows signing likewise requires your own certificate. Keep all signing material outside source control.

## Official references

- [Godot 4.6.3 download](https://godotengine.org/download/archive/4.6.3-stable/)
- [Godot Android export guide](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html)
- [Godot command-line export](https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html#exporting)

## Validation performed in the development environment

Both export commands completed successfully with official Godot 4.6.3 templates. The Windows output was inspected as PE32+ x86-64. Android APK signature verification passed (v2/v3), and its manifest and ARM64 library contents were inspected. This is build/package validation, not physical Windows or Android device testing. The GitHub Actions workflow is provided but has not been executed on GitHub.
