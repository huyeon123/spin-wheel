# Android fullscreen and safe controls (0.2.9)

## Verified behavior and fix

The previous export used `screen/immersive_mode=false`. Godot 4.6 shows the status/navigation bars in that mode and, without edge-to-edge, pads its root view. This is a source-supported explanation for the reported bands, not a diagnosis from the user's device pixels.

The Android preset now enables `screen/immersive_mode` and `screen/edge_to_edge`. The existing background fills the complete viewport; only the interactive main layout and modal cards use `SafeLayout.safe_rect`. The native window background also matches the app's ivory color.

`SafeLayout.resume_fullscreen()` runs at startup and focus/resume. On the Android UI thread it reacquires the current Activity and calls Godot's `enableEdgeToEdge(true, true)` and `enableImmersiveMode(true, true)`. The public window cutout policy is `ALWAYS` on API 30+, `SHORT_EDGES` on API 28–29, and untouched on older APIs. This matters because Android's default cutout policy can letterbox immersive content on older OS versions. No cutout height is guessed.

## Insets and keyboard

Godot's immersive `getDisplaySafeArea()` reports display cutouts only. A guarded AndroidRuntime/JavaClassWrapper bridge supplements it with measured stable system-bar and mandatory-gesture insets:

- API 30+: `WindowInsets.getInsetsIgnoringVisibility(systemBars | displayCutout | mandatorySystemGestures)`.
- API 24–29: stable inset getters; API 28 adds display-cutout safe inset getters; API 29 adds mandatory-system-gesture insets.
- Stable bar space remains reserved while bars are hidden. Swipe-revealed transient bars therefore do not cover controls or cause a jump. Android retains its normal transient-bar swipe behavior.
- IME is excluded from the native inset mask. Existing `virtual_keyboard_get_height()` handling clips against the pre-keyboard client rectangle, then intersects with the current viewport. A resized viewport never subtracts the IME twice; focused modal fields remain scrollable into view.
- Native and engine rectangles are intersected, never added. The combined rectangle is transformed once with `Control.get_screen_transform().affine_inverse()`. Bounds remain in Godot's Android window coordinates; no extra DPI scaling is applied.

Activity, Window and View references are reacquired per sample on the UI thread and are not stored. Only value types return through a deferred callable. Sampling is limited to once per 500 ms, shared by all controls/cards. Resume invalidates old generations; null pre-attachment measurements are retried. Samples expire after two seconds and stale-width samples are ignored.

All Android-only classes/singletons and Java methods are guarded dynamically. Java exceptions are checked immediately after Java calls; `get_exception()` is not a clearing operation. Godot clears the JNI exception internally and replaces its stored last exception on the next Java call. Public instance fields use public Java reflection because JavaObject does not expose instance fields as GDScript properties. No private APIs or access overrides are used.

If the bridge is absent or measurement fails, the existing Godot cutout/keyboard rectangle and ordinary layout padding remain usable. Missing bridge support logs one warning; this fallback cannot guarantee all transient-bar/gesture reservations. The current custom engine retains JavaClassWrapper, `get_exception` and `has_java_method`; the APK includes AndroidRuntimePlugin, so no custom native library rebuild was required.

## Validation and limits

Host geometry tests cover native/engine intersection, malformed/absent measurements, already-inset clients, transformed 2.25× screen coordinates, transient bars, keyboard resize/overlay, restoration, stale callback generations, main controls, full-bleed backgrounds and modal focus scrolling. Desktop/headless tests do not execute JNI or prove Samsung system-bar behavior.

Physical Android checks still needed: launch with gesture and three-button navigation, swipe bars in/out, open and dismiss the keyboard, switch apps and return, check the camera area, and open each modal. No Galaxy device was available for this change.

## Primary references

- [Godot 4.6 Android fullscreen/edge-to-edge and IME implementation](https://github.com/godotengine/godot/blob/4.6/platform/android/java/lib/src/main/java/org/godotengine/godot/Godot.kt)
- [Godot 4.6 native safe-area implementation](https://github.com/godotengine/godot/blob/4.6/platform/android/java/lib/src/main/java/org/godotengine/godot/GodotIO.java)
- [Godot 4.6 Android export flags](https://github.com/godotengine/godot/blob/4.6/platform/android/export/export_plugin.cpp)
- [Godot AndroidRuntime/JavaClassWrapper integration](https://docs.godotengine.org/en/4.6/tutorials/platform/android/javaclasswrapper_and_androidruntimeplugin.html)
- [Godot JavaClassWrapper exception contract](https://docs.godotengine.org/en/4.6/classes/class_javaclasswrapper.html)
- [Android WindowInsets API levels and semantics](https://developer.android.com/reference/android/view/WindowInsets)
- [Android cutout modes and immersive letterboxing](https://developer.android.com/develop/ui/views/layout/display-cutout)
