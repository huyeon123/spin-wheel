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

## Version 0.2.1 settings, history and drag continuity

- Gear opens global settings directly. Preset duration and winner-removal overrides live at the bottom of the roulette editor, retaining nullable inheritance and existing saved values.
- Desktop editor allows760 logical px; mobile stays inside its viewport. All delete-button states use compact8px padding, a44px target and10px safe right inset. Six viewport regressions cover glyph fit and field layout.
- History rows prioritize winner names, show timestamps secondarily when present, and use color dots only for saved valid colors. Per-preset isolation,100-record pagination and confirmed reset are preserved; legacy records without timestamps remain renderable.
- Removed ghost pinning to insertion markers. Independent actual editor/manager1px-pointer traces now show exactly1px ghost motion (previous maximum jumps57/64px), with no per-motion data mutation/rebuild. Grab offset remains fixed; marker draws behind the opaque ghost. Autoscroll does not move a stationary-pointer ghost.
- Fifteen suites: **11,850 checks passed**, no engine/script errors. Final cosmetic changes passed83 additional checks in the four affected suites. Desktop/mobile global settings, editor top/bottom and history captures are Linux-rendered app views; history screenshots use isolated sample records, not user data.
- Version0.2.1/Android versionCode7; package ID and local persistence paths unchanged. Windows user-PC launch and Android physical-device behavior are not claimed by cloud rendering.

## Version 0.2.2 selected-hover regression

- Reproduced using real pointer dispatch and framebuffer capture: selected CheckBox hover uses DRAW_HOVER_PRESSED, whose missing theme entries fell back to a white font and StyleBoxEmpty. Explicit hover_pressed styles/colors now cover ratio/percentage radios, inherited/custom duration, removal toggles and generic buttons. Selected soft-label contrast is strengthened without changing layout.
- Seventeen suites pass **12,143 checks**:15 headless suites11,852 plus288 native-rendered button-state checks and3 wheel-pixel checks. The button matrix covers9 roles across6 states and both selected/unselected values; actual text pixels and foreground/background contrast are checked. CI runs these two render-dependent suites under Xvfb/Mesa, never headless.
- Global settings/history bottom Close footers removed; topX, Escape/Android back and focus restoration remain. Final desktop/mobile captures checked.
- Wheel separators now render after all slice fills. Native pixel regression fails the old interleaved draw order and passes uniform current seams at rest/rotation. Shadow drawing and offset remain unchanged.
- Version0.2.2/Android code8; no persistence schema or user-data migration changes. Physical Windows handoff and Android device verification remain separate from cloud rendering.

## Version 0.2.3 portrait desktop startup

- Desktop starts in a portrait client window, preferring480×800 at100% scale, fitted to the current monitor's usable rectangle with margins and decoration reserves. Monitor coordinates are already pixels; DPI only scales desired dimensions. Negative monitor origins, taskbars, large decorations and small screens are covered. Mobile/web/headless/embedded/editor and explicit test window geometry are excluded.
- Window remains resizable, with a monitor-safe dynamic minimum and no aspect-ratio lock. No saved preset/settings/history fields change. Wayland placement/workarea information is compositor-limited, so additional panel space is reserved and placement is left to the compositor.
- Pure geometry tests pass2,766 checks over847 monitor/DPI combinations. Independent native X11 startup measured480×800 at(400,64) inside1280×900 workarea; native smoke passes2,770 checks including resize to520×800. This is not a Windows monitor/DPI runtime claim.
- Seventeen headless suites pass14,694 checks without app errors, including76 narrow-layer checks over six overlay types at480×800,390×700,360×560 and320×480. Native button-state288 and separator3 checks also passed, totaling14,985 checks across19 suites, plus the repeated2,770-check native startup smoke.
- Actual no-resolution-override main/editor/settings/manager portrait screenshots inspected. Version0.2.3/Android code9, same package and persistence paths.

## Version 0.2.4 close-icon geometry and fixed shadow

- Every layer uses a dedicated red18px close icon, centered in an unchanged40px hit target. Icon expansion is disabled; normal/hover/pressed/hover_pressed/focus/disabled styles share identical8px margins. This removes generic button padding differences that previously resized the fitted icon on hover.
- Native framebuffer tests cover eight actual layer types across five pointer/focus/disabled states, real close clicks, and four other icon controls. Red glyph bounds remain identical; each axis stays within0.5px of the target center. The close-icon suite passes248 checks.
- Main wheel shadow is a nonrotating sibling below the wheel, with unchanged3px downward offset, radius, alpha and color. It follows holder center/size, not wheel rotation. Static manager previews retain their unchanged shadow. Native34-check shadow regression covers cardinal rotations, both-direction drag/coast, resize and unchanged exterior shadow pixels.
- Final21 suites pass **15,267 checks**:17 headless14,694 plus native buttons288, separators3, close icons248 and shadow34. No app errors; software-renderer VSync warning is environmental. Matrix captures and actual portrait/mobile layers are inspected before release.
- Version0.2.4/Android code10. Existing data, wheel probabilities and portrait startup behavior are unchanged.

## Version 0.2.5 Android startup/export integrity

- User-reported Android splash followed by a blank screen was traced to the delivered APK's converted main scene: its root had no script. The script file itself loaded correctly. A stale795-byte binary scene from an earlier failed import had been reused. The unchanged-source clean export produces an871-byte scene with the script and initializes the UI.
- Negative checks reject the preserved delivered0.2.4 APK and locally built Windows EXE; positive checks pass the fresh0.2.5 APK and EXE. The previously user-reviewed Windows CI artifact came from a fresh checkout and is distinct from that stale local Library export.
- Builds now use fresh isolated staging and regenerate platform-specific converted export resources. Missing script/resource errors reject the build. Exact exported-scene gates run before outputs are copied for distribution, and therefore run in CI too.
- Final ARM64 APK SHA-256: `5af1ccc21efd12873cc4d310d3ff2f7134594cedcc9ea27b103abd253c83e5e3`. Package unchanged, version0.2.5/code11. Its public certificate exactly matches the delivered0.2.4 APK: `a30740b4b2f32490fbbe6d081f3a85db84859271d191b933ec57599eb9d5e8f1`. Update installation must preserve this signer; no uninstall/data reset is part of the fix.
- Exact-resource startup checks use the host Godot runtime and do not by themselves prove Android GPU/OS behavior. Separate Android software-emulator verification is tracked with the release; Samsung physical-device confirmation remains with the user. No gameplay, appearance, or size-optimization changes are included.

## Version 0.2.6 Android layout and input

- The user confirmed version0.2.5 starts successfully on Galaxy S25 Ultra. The cloud Android15 x86_64 software emulator stalled in system-server startup before app code executed; that attempt does not count as an Android runtime pass.
- Main layout uses the OS display-safe rectangle mapped through the viewport screen transform. Header/result, centered wheel and bottom spin/auxiliary rows have independent bounded regions. Android export uses non-immersive mode so status/navigation bars and display cutout are represented. Keyboard exclusion intersects the original client bounds with the current viewport, avoiding a second subtraction when the OS already resized it; focused modal fields scroll into view.
- Duration fields use a decimal numeric keyboard and strict plain-decimal parsing within1–30 seconds. Paste, text/IME input, exponents, expressions and non-finite values cannot silently change a stored amount. Existing fractional values remain unchanged when opened/closed.
- Newly created presets have exactly two unique-ID blank labels with1:1 weights. Drafts persist without sample substitution; spinning requires completed names. Existing presets/history are unchanged. Wheel labels increase2px with width-limited ellipsis and existing contrast selection.
- Native Android cutout/keyboard behavior for this new version still requires device confirmation; Linux rendering and pure safe-area coordinate tests are not a Samsung device test.
- Final regression: **15,439 checks passed across25 runs/24 distinct suites**, including92 mobile safe-area/keyboard geometry checks,32 headless duration checks plus37 real-input duration checks, and11 blank-preset persistence checks. Both exact exported APK/EXE startup gates independently pass. ARM64 APK SHA-256 `f87679ef4ba37a92fee9ae03e3d202afa97665cb5e68a4274c85661dc17bbc6d`; version0.2.6/code12, unchanged signer `a30740b4b2f32490fbbe6d081f3a85db84859271d191b933ec57599eb9d5e8f1`. Native-library extraction remains enabled; no size-experiment tradeoff is included.

## Version 0.2.7 lightweight Android test candidate

- Upper-center winner text uses32px and at most two lines. The reserved result region is104px, accounting for the Korean font's actual99px two-line minimum so it does not overlap the wheel on short/wide layouts. It remains plain text without a label/card.
- Opening the roulette editor focuses its neutral card rather than the name field. Direct entry, manager entry and close/reopen paths preserve this; explicit click/Tab still enters inputs. This removes automatic text-focus requests, while final Android keyboard behavior remains a device check.
- Android candidate uses the latest0.2.7 official release-template payload with only the ARM64 engine library replaced by the approved custom2D build. Existing package/signing identity, compressed native-library extraction and user storage remain unchanged. A separately signed official-engine fallback is retained. Ordinary CI APKs use the official engine and must not be confused with the custom test APK attached to the prerelease.
- Custom engine provenance, configuration and reproduction are in docs/custom-engine. Host exported-resource checks validate the exact app payload but do not execute the custom Android engine. Native GPU, Korean text/IME, sound, spin, save/restart, pause/back and installation size require Galaxy testing before promoting this engine beyond a test candidate.
- Final checks: **15,530 passed across27 runs/25 distinct suites**. Long-result80 and editor-focus21 headless plus21 native checks pass. Final custom/official APK and Windows exact-resource startup gates pass. Final custom APK is16,375,496bytes, SHA-256 `f609d53d5b70fd0527bcada18192aca1bcc8671c4e677da03f5343ff19327af7`, package unchanged/version0.2.7/code13, same public certificate. Independent ZIP comparison confirms only engine payload differs (excluding signature metadata); ELF64 AArch64 16KB alignment and APK zipalign pass.66 engine JNI exports remain; three Vulkan/Swappy-only exports are intentionally absent in the GL-only build. New native imports resolve in the packaged C++ runtime. The55,051,384-byte installed-storage model is not a Galaxy measurement.

## Version 0.2.8 audio and within-slice landing

- Replaced the previous one-shot spin sound with original32ms ratchet ticks driven by actual angular travel (24 virtual teeth/revolution).40ms minimum spacing and single-voice playback prevent overlap and queued catch-up bursts. The1.24s original major-key fanfare plays once after completion. Background/focus loss stops audio and suppresses the interrupted spin's remaining sound, including late fanfare after resume; a new spin starts a new sound session. Existing mute controls remain effective.
- WAVs are deterministic mono PCM16/22.05kHz, combined56,184bytes. Peaks−9.63dBFS/−6.94dBFS with additional runtime attenuation, silent endpoints and lowDC. Generator/provenance included; source synthesis validation runs in CI. The user approved the separate audition sample; the sample illustrates timbre/cadence and is not a recording of one actual random spin.
- Root cause of fixed stop locations was use of the selected slice's center_angle. Weighted selection remains unchanged; a second independent random draw now chooses a uniform landing point across that selected interval. Boundary exclusion is at most1e-10radians for ordinary slices, with a double-precision ULP guard for exceptionally tiny legacy intervals. Both directions use this target in the existing continuous trajectory; no last-frame random offset is added.
- Display-precision limit, without changing probabilities: with weights[1000000,1,1000000], the middle slice spans3.14159e-6rad. At its extreme endpoint, Godot's float32 display rotation can round over the boundary by1.07e-8rad (about0.000003px at250px radius). With200 slices,199 weights1000000 and one middle weight1, the3.15738e-8rad slice nearPI can contain no representable float32 display orientation; midpoint error is about7.6e-8rad (0.000019px). These subpixel cases are documented rather than assigned artificial minimum weights. Weighted outcome data and double-precision interval sampling remain independent of display quantization.
- Final regression: **16,087 checks across29 runs/27 distinct suites** (23 headless15,456 +6 native631). New audio453 and random-landing104 checks cover1/30s, both directions,40rad/s, repeat/removal, dense sampling across conditional interval bins, near-edge points, and endpoint continuity. The exact shipped APK passes the same557 new checks using its extracted bytecode/assets. Exact custom/officialAPK and Windows startup gates pass; final custom APK16,383,845bytes, SHA-256 `a4ea122dc79d4d43d1922d01b12847674298c374ae9ad766ce4411c19ac07517`, version0.2.8/code14 and unchanged certificate. Custom native engine is byte-identical to0.2.7; no actual-device success for that custom engine is claimed here.
- Common Control layers now enter with180ms fade and10px upward settling, and leave with140ms fade/downward retreat; no bounce. Lifecycle tokens cancel obsolete close callbacks on reopen, and modal blocking stays active through exit. Neutral editor focus remains. A static reduced_motion override skips motion; Godot4.6's exposed OS/DisplayServer API does not provide a reliable platform reduced-motion preference, so automatic OS preference detection is not claimed. Real390×844/60fps preview is docs/screenshots/overlay-motion-preview.mp4.
- Animation-integrated final0.2.8 regression supersedes the pre-animation count above: **16,133 checks across31 runs/28 distinct suites** (24headless15,479 +7native654). Dedicated real-duration transition23 checks pass in headless, native renderer, and exact exported APK; remaining legacy UI fixtures explicitly use reduced motion. The final APK passes580 additional shipped-asset checks (audio453+landing104+animation23), startup, certificate and alignment. Final APK SHA-256 `699a50c8f446626896e19f3fb15988bda30182eae50ae224627720d6a3a798c1`,16,383,845bytes, unchanged version0.2.8/code14. The earlier candidate remained an unpublished draft and was replaced before release.

## Version 0.2.9 history statistics and fullscreen safe areas

- Summary shows the latest three saved results above always-visible colored bars; detailed records retain 100-record pagination. Counts and observed percentages use the entire preset history, tested with 10,005 records. New wins store `slice_id`: duplicate names remain separate by identity, renamed items retain their group, and legacy exact-name groups never infer an ID from current slices. Group names come from the latest saved result and colors from the latest valid saved color within that group. Missing colors remain preserved and render neutrally when no valid saved color exists.
- Fixed ProgressBar's default integer step, which rounded fractional percentages despite correct labels. Initial statistics show five groups; each additional click adds at most 20. In a Linux headless 1,000-group fixture, unrestricted expansion took 1.63 seconds and created 5,150 nodes; bounded expansion took about 100 ms including six settling frames, with 276 nodes. Rapid final-batch clicks, narrow cards, animated detail return, expanded reset cancellation/confirmation and persistence are covered.
- **16,268 checks passed across 33 runs / 29 distinct suites:** 25 headless runs and eight Linux/Mesa rendered runs. History-statistics45 passes on both; mobile-layout137 covers raw screen-to-logical transforms, no double insets, transient system-bar/keyboard sequences, stale native generation rejection, invalid samples, focused-field scrolling and full-client background coverage. Existing button-state, close-icon, separator/shadow pixel, audio, landing and transition regressions remain passing. Final bridge-only edits passed mobile137 and app startup smoke again.
- Android export enables immersive and edge-to-edge. Background fills the client; controls and cards intersect measured cutout/system-bar/mandatory-gesture safe areas. Android API28+ uses the public cutout window mode. Insets are sampled on the UI thread, cached briefly, and invalidated on resume; IME exclusion is applied once against pre-keyboard geometry. Missing native bridge or unattached-window measurements retain Godot's safe-area fallback. API signatures and reflection behavior were reviewed against official Godot4.6.3 source.
- These are host simulation, source review and Linux rendering results. They do not execute the Android Java bridge or prove Galaxy cutout, transient bars, IME or resume behavior. Physical-device validation remains necessary; no Windows application was launched for this change. Exact final artifact checks are recorded separately after the final build.
- Final exact-artifact checks passed: custom and official Android APK startup/scene-script gates, and embedded Windows pack startup on host Godot. The custom APK additionally passed205 shipped-bytecode checks (history45 + mobile137 + animation23). Its exported command-line asset contains both fullscreen flags; the CI gate parses this binary asset and a missing-flag negative fixture fails as expected. Final custom APK is16,396,294bytes, SHA-256 `03fbbb3a5f34b5359d8d82f8bf295326ae0a8f4b830a12a0516a7288208ea92b`, version0.2.9/code15, unchanged package and certificate. APK zipalign and ELF16KB load alignment pass; ARM64 is the only packaged ABI. Custom and official fallback ZIP payloads differ only in the engine library, excluding signatures. The custom engine remains byte-identical to0.2.7, SHA-256 `1b092f0b6c9050fe1936dc604843b8ff407448932cee3480a23c6b2d793a0498`. Final Windows EXE SHA-256 `60358c6cdf4dd5601acb2fc87115ff3c726298412f4ab7fd42c29d631b6dc191`; reading its pack on Linux is not Windows runtime execution.

## Version 0.2.10 Android inset and keyboard correction

- Actual Galaxy feedback confirmed0.2.9 fullscreen, but exposed incorrect header/footer placement and keyboard overlap. Independent host reproduction found the missed runtime condition: Android embeds subwindows, and `Control.get_screen_transform()` then omits viewport stretch. At1080×2340 with480-wide logical content it returned identity while the actual viewport scale was2.25. Physical cutout90px became90logical pixels, and physical keyboard/navigation boundaries could fall beyond the logical viewport. The corrected accessor explicitly combines viewport final and canvas transforms.
- Exact engine-source audit found another Android-only failure: JNI primitive booleans arrive as Variant integer0/1, so direct comparison with `true` raises an invalid-operands error. This could interrupt sampling after fullscreen was enabled. Explicit Java Boolean normalization now covers integer/boolean/null returns.
- Native window, render-view and Godot-buffer coordinates are mapped explicitly, including nonzero render origins and different pixel dimensions. API30+ polls actual IME insets even when Godot's animation-reported height remains zero. Legacy zero/navigation-only measurements retain the engine fallback. Hidden status-bar space is no longer always reserved; measured cutout/visible bars remain safe. Bottom navigation/gesture reserves are retained, with mobile top12/bottom32 logical spacing. Existing modal safe-area layout and deferred focused-input scrolling now receive correct boundaries.
- **16,350 checks passed across35 runs /30 distinct suites** (26 headless and nine Linux/Mesa rendered runs). New Android-insets41 covers real embedded-root stretch, JNI values, differing native/buffer sizes, IME overlay/resized cases, origin/double-inset, gesture/three-button navigation, actual editor resizing/focused field/close/reopen and restored geometry. A temporary isolated renderer fixture demonstrates a full390×844 canvas with simulated keyboard occlusion; this is not an Android screenshot or native IME execution.
- Final APK additionally passes223 checks against its exact extracted bytecode (Android-insets41, mobile137, history45), plus exported scene-script startup, fullscreen/edge-to-edge flags, unchanged signing certificate and alignment. Version0.2.10/code16; SHA-256 `567e5a3110e829e0a2fc7425105c48f82b54e7608adbd3f65aa519d84eefb766`. Windows embedded-pack startup passes on host Godot; EXE SHA-256 `c6682e7880bec35ee8a2d5ef7c44ded3176a957ba25a54acb624bac955ce5728`. No Windows application was launched. New native Android behavior still requires device confirmation; host reproductions and simulated captures do not establish that confirmation.
