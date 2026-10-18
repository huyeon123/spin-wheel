extends Node
## Mechanical teeth follow actual travelled angle, never a free-running loop.
const TOOTH_ANGLE := TAU / 24.0
const MIN_INTERVAL := 0.04
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
var tick: AudioStreamPlayer
var victory: AudioStreamPlayer

func _ready() -> void:
 tick = AudioStreamPlayer.new(); tick.stream = preload("res://assets/spin.wav"); tick.volume_db = -5; tick.max_polyphony = 1; add_child(tick)
 victory = AudioStreamPlayer.new(); victory.stream = preload("res://assets/victory.wav"); victory.volume_db = -4; victory.max_polyphony = 1; add_child(victory)

func begin(angle: float, sound_enabled: bool) -> void:
 stop()
 enabled = sound_enabled
 active = true; suppressed = not foreground; completed = false
 previous_angle = angle; travel = 0; last_tick_time = -1

func advance(angle: float, now: float, sound_enabled: bool) -> void:
 enabled = sound_enabled
 if not active: return
 var delta := absf(angle - previous_angle)
 previous_angle = angle
 if not enabled or not foreground or suppressed:
  if is_instance_valid(tick): tick.stop()
  travel = 0
  return
 travel += delta
 if travel < TOOTH_ANGLE: return
 travel = fmod(travel, TOOTH_ANGLE)
 # Drop missed teeth instead of queuing a burst after a slow frame.
 if last_tick_time >= 0 and now - last_tick_time < MIN_INTERVAL: return
 last_tick_time = now
 tick_count += 1
 if is_instance_valid(tick): tick.play()

func finish(sound_enabled: bool) -> void:
 if not active or completed: return
 completed = true; active = false; enabled = sound_enabled
 if is_instance_valid(tick): tick.stop()
 if not enabled or not foreground or suppressed: return
 victory_count += 1
 if is_instance_valid(victory): victory.play()

func stop() -> void:
 active = false
 if is_instance_valid(tick): tick.stop()
 if is_instance_valid(victory): victory.stop()

func set_foreground(value: bool) -> void:
 foreground = value
 if not value:
  suppressed = true
  if is_instance_valid(tick): tick.stop()
  if is_instance_valid(victory): victory.stop()
