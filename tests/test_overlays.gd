extends SceneTree
const Model = preload("res://scripts/wheel_model.gd")
var checks := 0
var failures := 0
func _init() -> void:
 # Legacy behavior fixtures explicitly opt out; real timing is tested separately.
 load("res://scripts/wheel_layer.gd").reduced_motion = true
 if FileAccess.file_exists("user://state.json") or FileAccess.file_exists("user://state.json.bak"):
  push_error("Overlay tests require a fresh isolated user data directory.")
  quit(2)
  return
 call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)
func settle() -> void:
 for i in range(5): await process_frame
func all_of(node: Node, type: String) -> Array:
 var found := []
 for child in node.get_children():
  if child.is_class(type): found.append(child)
  found.append_array(all_of(child, type))
 return found
func run() -> void:
 root.size = Vector2i(480,800)
 var app = load("res://main.tscn").instantiate()
 root.add_child(app)
 current_scene=app
 await settle()
 check(not quit_on_go_back, "engine auto-quit disabled so back can close overlays")
 check(not app.editor_dialog.visible and not app.editor.is_visible_in_tree(), "editor hidden at launch")
 var hidden_bars := true
 for scroll in all_of(app, "ScrollContainer"):
  if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_NEVER: hidden_bars = false
 check(hidden_bars, "scroll containers hide bars while allowing scrolling")
 check(app.body.get_child_count() == 1, "main stage has no inline editor")
 var opener: Control = app.main_selector
 var gear: Button
 for button in all_of(app, "Button"):
  if button.tooltip_text == "설정": gear = button
 check(gear != null and gear.text.is_empty() and gear.icon != null, "main settings is icon-only gear")
 var branding_visible := false
 for label in all_of(app, "Label"):
  if label.is_visible_in_tree() and label.text in ["돌려봐", "작은 선택을, 즐거운 순간으로"]: branding_visible = true
 check(not branding_visible, "main has no persistent service title or subtitle")
 check(ProjectSettings.get_setting("application/boot_splash/image", "") == "res://assets/splash.png", "startup branding configured as native splash")
 app._settings_hub()
 await settle()
 var hub: Control
 for child in app.get_children():
  if child.get_meta("is_layer",false) and child.visible and child!=app.editor_dialog: hub = child
 check(hub != null and hub.exclusive and hub.title=="전체 설정", "gear opens global settings directly")
 app._close_top_layer()
 await settle()
 opener.grab_focus()
 app._open_editor()
 await settle()
 check(app.editor_dialog.visible and app.editor_dialog.exclusive, "editor opens modal")
 check(app.editor_dialog.card.position.x >= 0 and app.editor_dialog.card.position.y >= 0 and app.editor_dialog.card.size.x <= app.size.x and app.editor_dialog.card.size.y <= app.size.y, "portrait editor fits viewport")
 app._spin()
 check(not app.busy, "open editor blocks spins")
 app.preset.slices[0].weight = 1000000.0
 app.preset.slices[1].weight = 0.01
 app._change_mode(1)
 app._message("테스트", "알림")
 await settle()
 var info_nested := false
 for child in app.get_children():
  if child.get_meta("is_layer",false) and child.visible and child!=app.editor_dialog: info_nested = true
 check(info_nested and app.preset.mode == "percent", "informational layer opens above editor")
 app._close_top_layer()
 await settle()
 app.preset.mode = "ratio"
 for slice in app.preset.slices: slice.weight = 1.0
 app._refresh_editor()
 var weights := []
 for field in all_of(app.editor,"LineEdit"):
  if field.tooltip_text == "양의 정수 입력": weights.append(field)
 weights[0].text = "7"
 weights[0].text_changed.emit("7")
 app._close_editor()
 await settle()
 check(is_equal_approx(app.preset.slices[0].weight, 7.0), "close commits typed numeric input")
 check(Model.load_data().presets[0].slices[0].weight == 7.0, "close saves typed numeric input")
 check(root.gui_get_focus_owner() == opener, "close restores opener keyboard focus")
 app._open_editor()
 app._change_mode(1)
 await settle()
 for child in app.get_children():
  if child.get_meta("is_layer",false) and child.visible and child!=app.editor_dialog: app._close_top_layer()
 app.preset.slices[0].weight = 12.0
 app._definition_changed()
 app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 await settle()
 check(not app.editor_dialog.visible, "Android back closes editor")
 check(app.spin_button.disabled and Model.load_data().presets[0].slices[0].weight == 12.0, "invalid percent draft preserved on back")
 app._open_editor()
 app._confirm("Test", "Test", func(): pass)
 await settle()
 app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 await settle()
 check(app.editor_dialog.visible, "back closes nested confirmation before editor")
 app._close_top_layer()
 await settle()
 check(not app.editor_dialog.visible, "second back closes editor")
 app._settings()
 await settle()
 var settings: Control
 for child in app.get_children():
  if child.get_meta("is_layer",false) and child != app.editor_dialog and child.visible: settings = child
 check(settings != null and settings.exclusive, "global settings is modal")
 var seconds = all_of(settings, "LineEdit").filter(func(f):return f.get_meta("duration_input",false))[0]
 seconds.text = "9.5"
 app._close_top_layer()
 await settle()
 check(app.data.settings.duration == 9.5 and Model.load_data().settings.duration == 9.5, "settings back commits and saves typed duration")
 app._open_editor()
 app._preset_settings()
 await settle()
 check(app.editor_dialog.visible and app._top_layer()==app.editor_dialog, "preset settings live inside editor")
 app._close_top_layer()
 await settle()
 app._change_mode(0)
 app.data.settings.duration = 1.0
 app.data.settings.sound = false
 app._spin()
 app._open_editor()
 app._settings()
 app._preset_settings()
 check(app.busy and not app._has_layer() and app.main_selector.disabled, "spin blocks every settings entry and preset switch")
 await create_timer(1.2).timeout
 check(not app.busy and app.preset.history.size() == 1, "spin finishes after modal workflow")
 app._open_editor()
 await settle()
 var escape := InputEventKey.new()
 escape.keycode = KEY_ESCAPE
 escape.pressed = true
 Input.parse_input_event(escape)
 await settle()
 check(not app.editor_dialog.visible, "Escape closes editor")
 app.queue_free()
 await settle()
 for suffix in ["", ".bak", ".tmp"]:
  DirAccess.remove_absolute("user://state.json" + suffix)
 print("OVERLAY_QA: ", checks, " checks, ", failures, " failures")
 quit(1 if failures else 0)
