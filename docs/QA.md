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

## Version 0.1.3 Windows feedback corrections

- Reproduced blank-result bug: stored nonempty winner label collapsed to 1px inside a 49px shrinking badge. Fixed text sizing, moved winner to centered plain text between preset selector and wheel, removed badge, and reduced excessive spacing. Both empty and actual completed-spin screenshots checked on desktop/mobile-size layouts.
- All selectors now use an in-app custom Button/PopupPanel component with consistent field, focus and selected states, anchored dropdown placement, keyboard/back handling and transparent rounded corners. No native OptionButton popup dependency.
- Dialog viewport backgrounds are transparent and title/body corner shapes are consistent; square background leaks removed.
- Explicit equal-distribution: ratios all1; percentage integer total100 (three entries34/33/33). Positive integer-only new weight input in both modes; invalid/overflow text rejected.
- Legacy fractional values, including100000.5, remain accurately displayed and unchanged until explicit edit/conversion. Integer conversion uses constrained largest-remainder allocation, warns if probabilities change, and rejects >100 positive-percent entries.
- All8 suites pass:10,165 model+22 UI+4 layout+26 overlay+35 gesture+31 result+11 selector+129 integer=**10,423 checks**.
- Android0.1.3/versionCode4, same package and persistence schema. No migration deletes existing presets/history/settings. Windows native runtime verification is a subsequent local task; this cloud pass renders via Linux Godot.

## Version 0.2.0 approved redesign and interaction verification

- Replaced every app modal with fixed Control overlays: no native Window/PopupPanel decoration, dragging or resizing. Anchored internal choice menus remain Control-based. Fields and controls have visible neutral edges; primary actions use teal and favorite stars use yellow.
- Main preset name opens the separate manager with weighted miniature previews, select/edit/delete/add actions, favorite toggles and manual order handles. Main wide spin action is separated from reset/edit/history icons. Swipe remains available.
- Roulette editor contains the existing preset name, exclusive ratio/percentage radio controls, integer inputs, explicit equal distribution and reorder handles. Switching mode explicitly equalizes (ratio1 each, percent integer total100). Existing stored fractions are not changed merely by loading.
- Optional favorite defaults false for legacy saves. Favorites never sort automatically. Manual preset/slice array order survives save/reload. Rename keeps the same preset ID, history and settings. Pure reorder preserves removed-winner round state.
- Handle-only reorder supports mouse/touch, an8px threshold, ghost/insertion line, edge autoscroll, Alt+Up/Down, focus-following rebuilds, and Escape/back/focus-loss cancellation. GUI touch emulation is enabled; wheel ignores emulated duplicate mouse events.
- Real viewport-dispatched selection and reorder tests report no detached-viewport input errors. Hidden native context menus are disabled; focus trap includes internal SpinBox and color controls.
- Twelve suites: **10,539 checks passed** (full run10,538 plus a new placeholder-color regression; modified manager/reorder/fixed-layer suites rerun after final visual fixes), no engine/script errors. Supplementary actual add/drag captures verified readable placeholders and separated insertion-line/ghost text.
- Desktop and390×844 screenshots are actual Linux Godot rendering, not Windows/Android device captures. Windows runtime confirmation remains a subsequent user-PC step. Android0.2.0/versionCode6, unchanged package and signing path; no data migration deletes presets/history/settings.
