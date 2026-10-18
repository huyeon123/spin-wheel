extends SceneTree
func _initialize() -> void:
 if FileAccess.file_exists("user://state.json"): quit(2); return
 call_deferred("run")
func radios(node: Node) -> Array:
 var out := []
 if node is CheckBox: out.append(node)
 for child in node.get_children(): out.append_array(radios(child))
 return out
func run() -> void:
 var app = load("res://main.tscn").instantiate(); root.add_child(app); current_scene=app
 for i in range(5): await process_frame
 app._open_editor()
 for i in range(8): await process_frame
 var radio: CheckBox = radios(app.editor)[0]
 var move := InputEventMouseMotion.new(); move.position=radio.get_global_rect().get_center(); root.push_input(move,true)
 for i in range(3): await process_frame
 print("SELECTED=",radio.button_pressed," HOVER=",radio.is_hovered()," MODE=",radio.get_draw_mode()," hover_pressed font=",radio.get_theme_color("font_hover_pressed_color")," bg=",radio.get_theme_stylebox("hover_pressed").get_class())
 root.get_texture().get_image().save_png("res://build/hover.png")
 quit()
