extends Node
## Android-only finite pulses follow actual angular travel, never a timer loop.
const TOOTH_ANGLE := TAU / 24.0
const MIN_INTERVAL := 0.1
const TICK_DURATION_MS := 10
const TICK_AMPLITUDE := 0.25
const VICTORY_DURATION_MS := 40
const VICTORY_AMPLITUDE := 0.55

var enabled := true
var foreground := true
var active := false
var suppressed := false
var completed := false
var previous_angle := 0.0
var travel := 0.0
var last_tick_time := -1.0
var tick_count := 0
var victory_count := 0
var cancel_count := 0
# Optional test sinks exercise the exact production timing without hardware.
var vibration_callback := Callable()
var cancel_callback := Callable()
var _pulse_pending := false
var _android_wrapper: Object
var _android_vibrator: Variant

func _ready() -> void:
 _prepare_native_cancel()

func begin(angle: float, haptics_enabled: bool) -> void:
 stop()
 enabled = haptics_enabled
 active = true; suppressed = not foreground; completed = false
 previous_angle = angle; travel = 0.0
 # Keep the rate limit across drag-to-spin handoff and rapidly repeated spins.

func advance(angle: float, now: float, haptics_enabled: bool) -> void:
 set_enabled(haptics_enabled)
 if not active: return
 if not is_finite(angle) or not is_finite(now): return
 var delta := absf(angle - previous_angle)
 previous_angle = angle
 if not enabled or not foreground or suppressed:
  travel = 0.0
  return
 travel += delta
 if travel < TOOTH_ANGLE: return
 travel = fmod(travel, TOOTH_ANGLE)
 # Discard crossed teeth, including rate-limited teeth, rather than queueing.
 if last_tick_time >= 0.0 and now - last_tick_time < MIN_INTERVAL: return
 last_tick_time = now
 tick_count += 1
 _vibrate(TICK_DURATION_MS, TICK_AMPLITUDE)

func finish(haptics_enabled: bool) -> void:
 set_enabled(haptics_enabled)
 if not active or completed: return
 completed = true; active = false; travel = 0.0
 _cancel_pulse()
 if not enabled or not foreground or suppressed: return
 victory_count += 1
 _vibrate(VICTORY_DURATION_MS, VICTORY_AMPLITUDE)

func set_enabled(value: bool) -> void:
 if enabled == value: return
 enabled = value
 travel = 0.0
 if not value: _cancel_pulse()

func stop() -> void:
 active = false; travel = 0.0
 _cancel_pulse()

func set_foreground(value: bool) -> void:
 foreground = value
 if not value:
  # Do not replay this session's ticks or victory after returning to the app.
  suppressed = true; travel = 0.0
  _cancel_pulse()

func _exit_tree() -> void:
 stop()

func _vibrate(duration_ms: int, amplitude: float) -> void:
 if vibration_callback.is_valid():
  _pulse_pending = true
  vibration_callback.call(duration_ms, amplitude)
 elif OS.has_feature("android"):
  _pulse_pending = true
  Input.vibrate_handheld(duration_ms, amplitude)
 # Desktop, including Windows, never calls a vibration API.

func _cancel_pulse() -> void:
 if not _pulse_pending: return
 _pulse_pending = false
 cancel_count += 1
 if cancel_callback.is_valid():
  cancel_callback.call()
 elif OS.has_feature("android"):
  if _android_vibrator == null: _prepare_native_cancel()
  _java_call(_android_vibrator, &"cancel")
 # Godot 4.6.3 Godot.kt ignores duration <= 0. Never use vibrate_handheld(0)
 # as cancellation. AndroidRuntime invokes public Vibrator.cancel directly,
 # synchronously with the same render-thread JNI calls used by Input. If a
 # future engine omits the bridge, existing pulses still end in 10/40 ms.

func _prepare_native_cancel() -> void:
 if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime") \
   or not Engine.has_singleton("JavaClassWrapper"): return
 _android_wrapper = Engine.get_singleton("JavaClassWrapper")
 var runtime := Engine.get_singleton("AndroidRuntime")
 var context: Variant = _java_call(runtime, &"getApplicationContext")
 _android_vibrator = _java_call(context, &"getSystemService", ["vibrator"])

func _java_call(target: Variant, method: StringName, args: Array = []) -> Variant:
 if not target is Object or not is_instance_valid(target): return null
 var is_java: bool = target.has_method("has_java_method")
 if is_java:
  if not target.call("has_java_method", method): return null
 elif not target.has_method(method):
  return null
 var value: Variant = target.callv(method, args)
 if is_java and _android_wrapper.call("get_exception") != null: return null
 return value
