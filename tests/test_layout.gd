extends SceneTree
var failures := 0
func _init() -> void: call_deferred("run")
func settle() -> void:
 for i in range(5): await process_frame
func fits(app: Control, label: String) -> void:
 var width: float = app.content_scroll.global_position.x + app.content_scroll.size.x
 if width > app.size.x + 1:
  failures += 1
  push_error(label + " exceeds viewport: " + str(width) + " > " + str(app.size.x))
 print("LAYOUT ", label, " app=",app.size," body=",app.body.size," right=",width)
func run() -> void:
 root.size = Vector2i(480,800)
 var app = load("res://main.tscn").instantiate()
 root.add_child(app)
 await settle()
 fits(app, "default portrait")
 app.preset.name = "가".repeat(40)
 for s in app.preset.slices: s.name = "나".repeat(40)
 app._refresh_editor()
 app._refresh_wheel()
 await settle()
 fits(app, "long Korean names portrait")
 app.preset.mode = "percent"
 app._refresh_editor()
 await settle()
 fits(app, "percent portrait")
 root.size = Vector2i(1280,820)
 await settle()
 fits(app, "long Korean names desktop")
 print("LAYOUT_QA: 4 checks, ",failures," failures")
 quit(1 if failures else 0)
