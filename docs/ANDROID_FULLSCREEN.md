# Android fullscreen and safe controls (0.2.10)

## Causes identified after Galaxy feedback

Fullscreen itself worked in 0.2.9, but three reported symptoms shared a coordinate error: an excessively low header, insufficient bottom-navigation clearance, and a modal that did not visibly react to the keyboard.

Godot 4.6.3 forces embedded subwindows on Android. `CanvasItem.get_screen_transform()` uses the window's popup transform, which is identity when subwindows are embedded. The old helper therefore omitted viewport stretching and treated native pixels as logical UI units. An actual embedded-root host test reproduces this: the old transform has scale 1 while the correct viewport transform is 2.25. With that error a physical keyboard boundary can remain below the entire logical viewport, so intersection never shrinks the card. The earlier synthetic tests manually supplied the correct scale and did not exercise this runtime path.

A second Android-only issue affected native sampling: Godot's JNI can expose a Java `jboolean` as an integer Variant. Comparing that directly with `true` is invalid in GDScript. `java_truth()` now normalizes integer, Boolean and null results explicitly.

Two additional weaknesses were removed: native samples were previously discarded whenever decor width differed from the render-buffer width, and keyboard avoidance depended solely on Godot's IME animation callback. A decor/buffer mismatch was not measured on the user's Galaxy; it is a corrected assumption rather than a claimed device observation.

## Fullscreen remains enabled

Android exports retain `screen/immersive_mode=true` and `screen/edge_to_edge=true`. The background fills the complete viewport; only controls and modal cards use the safe rectangle. The native window background matches the app's ivory color.

At startup and focus/resume, `resume_fullscreen()` reacquires the Activity on its UI thread and calls Godot's edge-to-edge and immersive APIs. The public cutout policy remains `ALWAYS` on API 30+, `SHORT_EDGES` on API 28–29, and untouched on older APIs. Android's default cutout policy can otherwise letterbox immersive content on older versions. No device-specific resolution or guessed cutout size is used.

## Coordinate and inset pipeline

1. Read current native WindowInsets. API 30+ WindowMetrics provides full native window bounds. Read the actual Godot render View's drawing rectangle, then use `decor.offsetDescendantRectToMyCoords` to express it in native window coordinates. A Java Rect object is used because Godot copies primitive array arguments, so Java `int[]` output parameters would not update a GDScript array.
2. Intersect native engine cutout and native control insets. The top reserves the actual cutout and visible bars, without an additional hidden-status-bar reservation. Bottom navigation and mandatory gesture space remain reserved while immersive bars hide.
3. Clip the native keyboard boundary. API 30+ polls `getInsets(Type.ime())`, including zero on dismissal, instead of depending on an animation event. API 24–29 uses a system-bottom inset larger than stable navigation as positive keyboard evidence; ambiguous zero/nav-only readings retain the Godot height fallback.
4. Map the native safe rectangle through the measured render View rectangle into Godot buffer pixels. Differing buffer and view dimensions are supported; already-resized or offset views are intersected, not inset twice.
5. Convert buffer pixels to control-local units with `Viewport.get_final_transform() * Control.get_global_transform_with_canvas()`, plus the window origin. This retains stretch with embedded subwindows.

Main mobile controls add 12 logical pixels above the header and 32 below the bottom actions, inside the measured safe bounds. This is not a fixed percentage of the display. Desktop spacing is unchanged.

The existing modal layout then shrinks and recenters its card in the corrected visible area. Its scrolling container ensures the already-focused field is visible after container layout settles. Opening the editor still focuses the card rather than an input, so it does not summon the keyboard automatically.

## Lifetime, compatibility and fallback

Activity/Window/View references are reacquired on the Android UI thread and are not retained. Only value types return through a deferred callable. JNI sampling is shared and throttled to 200 ms; the scene checks cached geometry every 100 ms. Resume invalidates previous callback generations, samples expire after two seconds, and null pre-attachment measurements retry without collapsing the interface.

Android classes, singletons and Java methods are dynamically guarded. Java exceptions are checked immediately after Java calls; `get_exception()` does not itself clear the stored result. Public fields use public reflection with no access override. The custom engine retains the required Java wrapper APIs and the APK includes AndroidRuntimePlugin; no native library rebuild was required.

If the bridge is absent or a sample fails, Godot cutout/keyboard measurements remain available through the corrected embedded-root transform. The fallback cannot guarantee all native navigation/IME information. A missing bridge logs one warning.

## Reproducing regression coverage

Run `tests/test_android_insets.gd` and `tests/test_mobile_layout.gd` with isolated user-data directories, as configured in CI. These cover embedded-root scaling, Java Boolean normalization, native/render size mismatch, render origin, IME without an engine event, navigation insets and focused-field visibility. Host tests do not exercise Android JNI or a device compositor; verify keyboard and navigation behavior on the target device separately.

## Primary references

- [Godot 4.6.3 Android embedded-subwindow initialization](https://github.com/godotengine/godot/blob/4.6.3-stable/main/main.cpp)
- [Godot CanvasItem screen transform](https://github.com/godotengine/godot/blob/4.6.3-stable/scene/main/canvas_item.cpp)
- [Godot Window popup/final transforms](https://github.com/godotengine/godot/blob/4.6.3-stable/scene/main/window.cpp)
- [Godot JNI return conversion](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/android/java_class_wrapper.cpp)
- [Godot fullscreen and IME implementation](https://github.com/godotengine/godot/blob/4.6/platform/android/java/lib/src/main/java/org/godotengine/godot/Godot.kt)
- [Godot native safe-area implementation](https://github.com/godotengine/godot/blob/4.6/platform/android/java/lib/src/main/java/org/godotengine/godot/GodotIO.java)
- [Godot AndroidRuntime/JavaClassWrapper integration](https://docs.godotengine.org/en/4.6/tutorials/platform/android/javaclasswrapper_and_androidruntimeplugin.html)
- [Android WindowInsets API](https://developer.android.com/reference/android/view/WindowInsets)
- [Android WindowMetrics](https://developer.android.com/reference/android/view/WindowMetrics)
- [Android ViewGroup coordinate conversion](https://developer.android.com/reference/kotlin/android/view/ViewGroup)
- [Android cutout modes](https://developer.android.com/develop/ui/views/layout/display-cutout)
