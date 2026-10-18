# Independent QA — Spin Wheel

2026-10-18. Runtime used: Linux Godot 4.6.3, headless.

## Executed
- Existing `tests/test_model.gd`: 10,165 checks passed.
- Independent `test_ui.gd`: 22 checks passed, including actual timed spin completion.
- Main application headless smoke: `UI_SMOKE_OK`.
- Windows output recognized by `file` as PE32+ GUI executable, x86-64.
- Android `apksigner verify --verbose`: valid v2 and v3 signatures.
- Android manifest: `io.github.huyeon123.spinwheel`, version 0.1.1, minimum SDK 24, target SDK 36.

UI checks covered global settings inheritance, per-preset overrides, new preset independence, spin editing lock, saved last-spun identity, pending spins not creating history, completion history, winner removal retaining original definition, visible pointer matching winning label, stopping below two active slices, restoring round without deleting history, valid percent conversion, invalid percent blocking spins while saving draft/history, separate histories, browsing not changing last-spun identity, reopening state, and interrupted spin not falsely committing winner/removal.

## Source publication audit
No secrets, credentials, saved user state, signing files or private user files identified in publishable source. `.godot/` and `build/` are excluded. Font-license attribution contains public author emails. Android build uses development signing and the stable package identifier io.github.huyeon123.spinwheel; not a store release.

## Issues found and resolved
- Loader accepted empty preset collection, while UI assumed index 0. Fallback implemented and tested.
- UI originally allowed >100 presets although persistence rejects above 100. Creation guard and disabled button now enforce the limit.
- History rendering originally instantiated a label for every record; now paginates 100 records at a time without trimming stored records.

## Limits
This report does not establish actual Windows or Android runtime behavior, touch interaction, audio-device playback, visual layout, physical-device performance, or GitHub CI execution. Visual QA was separately coordinated with build lead. Initial sandbox run needed writable XDG data/cache directories; rerun succeeded with isolated directories, avoiding existing user state.

## Reproduction
Run with a fresh writable `XDG_DATA_HOME` to avoid existing state affecting tests, and set `XDG_CACHE_HOME` to writable directory. From project directory:

    godot --headless --path . --script tests/test_model.gd
    godot --headless --path . --script tests/test_ui.gd
    godot --headless --path . -- --smoke

## Final regression updates
- 22 UI action checks passed again after integration.
- Four headless layout checks now pass: default portrait, 40-character Korean preset and slice names portrait, percent-mode portrait, long Korean names desktop. Initially reproduced overflow (968px, then769px into480px); title ellipsis plus OptionButton clipping resolved it to424px body width.
- Source confirms 100-preset creation guard and 100-entry history display pagination. Full history storage remains untrimmed.
- Inspected intermediate real desktop screenshot: Korean font renders, wedge colors/labels/pointer and top-right result are clear. Final screenshots inspected below.
- UI action test must use isolated fresh XDG_DATA_HOME. Existing-state refusal and cleanup are included in the published test.

## Final rendered inspection and measurements

Native Godot Linux renderer, Xorg dummy display, Mesa llvmpipe software OpenGL, 2026-10-18:
- Desktop screenshot: `screenshots/desktop.png` (1280×960).
- Phone-sized window: `screenshots/mobile.png` (390×844). This is desktop rendering at phone dimensions, not an Android device screenshot.
- Korean text, pastel slices, pointer, main action, scrolling layout visually inspected.
- Final long-name layout regressions: 4/4 passed after clipping preset selector/title.
- Observed at idle: 60 FPS monitor, engine process sample 4.86 ms, static engine allocation 57.35 MB.
- Observed while spinning: 60 FPS monitor, process sample 18.11 ms, static engine allocation 57.42 MB; 98 draw calls.
- Samples came from `tests/benchmark.gd`; static allocation is not OS RSS and process samples are not p95 frame timing. Software-rendered Linux results do not establish Windows/Android hardware performance.
- Windows/Android binaries packaged and statically checked; not executed on Windows or a physical Android device.

## Version 0.1.1 requested UI revisions

- Removed permanent service title/subtitle; brand appears in native startup splash without an artificial delay.
- Centered preset chooser in top bar; right-side gear icon is the only settings entrance, with tooltip/accessibility name.
- Gear opens a modal navigation layer; editor, current-preset overrides and global settings each occupy separate layers.
- Editor scrolls inside the mobile-size overlay. Main wheel is never part of the editor layout.
- 25 overlay checks passed, covering typed SpinBox commit/save, Escape, Android back (engine autoquit disabled), nested confirmation/information dialogs, focus restoration, edit locks, gear hub transitions and startup-only branding.
- Full regression: 10,165 model checks, 22 UI action checks, 4 responsive layout checks, 25 overlay checks.
- Four final native Linux-rendered screenshots inspected: desktop/mobile-size main and editor layers. Mobile dimensions are 390×844; this remains a resized desktop window, not a physical Android capture.
- Export version is 0.1.1, Android versionCode 2; target package remains io.github.huyeon123.spinwheel.

## Version 0.1.2 gesture and visual revision

- Direct finger/mouse angular dragging; release retains position and velocity, then completes weighted fair result at configured coast duration in either direction.
- 32 gesture checks: center/outside/tiny/stale gestures, touch cancellation, focus loss/pause, duplicate emulated mouse and multiple pointers, drag locks, angle seam continuity, CW/CCW endpoint, no double history, slow accepted flick velocity.
- Full current suite: 10,165 model +22 UI +4 layout +26 overlays +32 gestures =10,249 checks.
- Main styling removes permanent cards and unnecessary captions in favor of tonal background, large wheel and floating icon controls. Scrollbars hidden while scrolling remains available.
- Timing is deliberate game animation, not physical friction simulation: continuous position/release velocity, configured duration and weighted outcome are preserved; low speed/short duration may require smooth acceleration.
- Android versionName0.1.2/versionCode3, same package. Windows/physical Android runtime remains unverified.

### Final detail polish
- Neutral ivory background with a restrained control accent; no decorative gradient or marketing captions.
- Wheel/control group vertically centered in the remaining viewport; mobile wheel enlarged.
- Vector pointer anchored exactly on wheel centerline instead of font-glyph placement.
- Antialiased rim and center circles. Slice text dynamically chooses white or dark ink using relative luminance contrast for user-selected colors.

Final detail regression total: **10,252 checks passed** (10,165 model,22 UI,4 layout,26 overlays,35 gestures). Additional checks verify vector-pointer center alignment and white-on-black/dark-on-white slice-label selection. Latest four screenshots reflect the centered, enlarged wheel and neutral ivory finish.
