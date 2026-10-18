extends RefCounted
## Scalar angular motion only; no physics server, body or collision dependency.
const FRICTION := 2.4 # radians / second squared
const MAX_SPEED := 40.0
const MIN_RELEASE_SPEED := 0.6

static func sample(start_angle: float, initial_velocity: float, elapsed: float) -> Dictionary:
 if not is_finite(start_angle) or not is_finite(initial_velocity) or not is_finite(elapsed):
  return {"angle": 0.0, "velocity": 0.0, "finished": true}
 var speed := minf(absf(initial_velocity), MAX_SPEED)
 var stop_time := speed / FRICTION
 var t := clampf(elapsed, 0.0, stop_time)
 var direction := signf(initial_velocity)
 return {"angle": start_angle + direction * (speed * t - 0.5 * FRICTION * t * t), "velocity": direction * maxf(0.0, speed - FRICTION * t), "finished": elapsed >= stop_time}
