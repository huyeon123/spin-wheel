extends SceneTree
const Reorder = preload("res://scripts/reorder_handle.gd")
# Visual-only capture harness; run under a fresh XDG_DATA_HOME.
func _initialize() -> void:
 if FileAccess.file_exists("user://state.json"):
  push_error("Refusing visual capture over existing user data"); quit(2); return
 call_deferred("run")
func find_handle(node: Node) -> Control:
 if node is Reorder: return node
 for child in node.get_children():
  var found := find_handle(child)
  if found != null: return found
 return null
func run() -> void:
 var app = load("res://main.tscn").instantiate(); root.add_child(app); current_scene = app
 for i in range(5): await process_frame
 var kind := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "add"
 if kind == "blank-editor":
  app._new_preset(); app._open_editor()
 elif kind == "add": app._add_preset_dialog()
 elif kind == "history":
  for i in range(5):
   var slice: Dictionary = app.preset.slices[i % app.preset.slices.size()]
   app.preset.history.append({"name":slice.name,"color":slice.color,"at":"2026-10-18 15:%02d:00" % (18+i*3)})
  app._history()
 elif kind == "global": app._settings()
 elif kind == "preset-drag":
  for title in ["점심 메뉴","주말에 할 일"]:
   var p: Dictionary = app.Model.default_data().presets[0].duplicate(true); p.id = app._id(); p.name = title; app.data.presets.append(p)
  app.preset.favorite = true; app._preset_manager()
 else: app._open_editor()
 for i in range(8): await process_frame
 if kind == "editor-bottom":
  app.editor_dialog._scroll.scroll_vertical = int(app.editor.get_combined_minimum_size().y)
 if kind.ends_with("drag"):
  var target: Control = app.manager_dialog if kind == "preset-drag" else app.editor
  var handle := find_handle(target)
  var pos := handle.get_global_rect().get_center()
  handle._begin(pos,-1); handle._move(pos + Vector2(0,160))
 await create_timer(.25).timeout
 root.get_texture().get_image().save_png("res://build/capture.png")
 quit()
