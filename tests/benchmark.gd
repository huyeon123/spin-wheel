extends SceneTree
## Optional developer measurement. Run with a real display, not --headless.
## Uses isolated user data; reports environment-specific observations, not device guarantees.
func _init() -> void:
 if FileAccess.file_exists("user://state.json"):
  push_error("Benchmark requires a fresh isolated user data directory.")
  quit(2)
  return
 call_deferred("run")
func run() -> void:
 var app = load("res://main.tscn").instantiate()
 root.add_child(app)
 await create_timer(2).timeout
 print("IDLE fps=", Engine.get_frames_per_second(), " process_seconds=", Performance.get_monitor(Performance.TIME_PROCESS), " static_memory_bytes=", Performance.get_monitor(Performance.MEMORY_STATIC), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 app.data.settings.sound = false
 app.data.settings.duration = 4.0
 app._spin()
 await create_timer(2).timeout
 print("SPIN fps=", Engine.get_frames_per_second(), " process_seconds=", Performance.get_monitor(Performance.TIME_PROCESS), " static_memory_bytes=", Performance.get_monitor(Performance.MEMORY_STATIC), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 await create_timer(2.2).timeout
 quit()
