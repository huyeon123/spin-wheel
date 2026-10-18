extends SceneTree
# Run this external script against the extracted APK assets, never the source project.
func _initialize() -> void:
 call_deferred("_verify")

func _verify() -> void:
 var scene = load("res://main.tscn")
 if not scene is PackedScene:
  push_error("EXPORTED_STARTUP_FAILED: main scene missing")
  quit(1); return
 var app = scene.instantiate()
 if app.get_script() == null:
  push_error("EXPORTED_STARTUP_FAILED: exported root has no script")
  app.free(); quit(1); return
 root.add_child(app)
 await process_frame
 await process_frame
 if not is_instance_valid(app.get("wheel")) or not is_instance_valid(app.get("spin_button")):
  push_error("EXPORTED_STARTUP_FAILED: application UI did not initialize")
  app.free(); quit(1); return
 if app.wheel.size.x <= 0 or app.wheel.size.y <= 0 or app.preset.slices.size() < 2:
  push_error("EXPORTED_STARTUP_FAILED: wheel or initial preset is invalid")
  app.free(); quit(1); return
 print("EXPORTED_STARTUP_OK: root script attached, UI built, wheel and preset valid")
 app.free()
 quit(0)
