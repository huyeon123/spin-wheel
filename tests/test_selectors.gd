extends SceneTree
var failures:=0
var checks:=0
func _init() -> void:
 if FileAccess.file_exists("user://state.json") or FileAccess.file_exists("user://state.json.bak"):
  push_error("Selector tests require isolated user data.");quit(2);return
 call_deferred("run")
func settle() -> void:
 for i in range(5): await process_frame
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures+=1;push_error(label)
func run() -> void:
 root.size=Vector2i(480,800)
 var app=load("res://main.tscn").instantiate();root.add_child(app);await settle()
 check(root.gui_embed_subwindows,"popups use embedded rendering rather than native OS chrome")
 app._new_preset();app._select_preset(0)
 app.main_selector.open_choices();await settle()
 check(app.main_selector.popup.visible and app.main_selector.popup is PopupPanel,"main selector uses in-app PopupPanel")
 check(app.main_selector.popup.transparent_bg,"selector transparent viewport preserves round corners")
 app._spin();check(not app.busy,"selector popup blocks spin")
 app._close_top_layer();await settle()
 check(not app.main_selector.popup.visible,"back closes selector popup")
 app.main_selector.open_choices();await settle()
 app.main_selector.choose(1);await settle()
 check(app.preset==app.data.presets[1],"main selector changes preset")
 app._open_editor();await settle()
 app.selectors.open_choices();await settle()
 check(app.selectors.popup.visible and app.editor_dialog.visible,"selector opens inside exclusive editor")
 check(app.selectors.popup.position.x>=0 and app.selectors.popup.size.x<=app.editor_dialog.size.x,"editor selector width fits")
 app._close_top_layer();await settle()
 check(app.editor_dialog.visible and not app.selectors.popup.visible,"back closes choices before editor")
 var popup_style: StyleBoxFlat=app.selectors.popup.get_theme_stylebox("panel")
 check(popup_style.corner_radius_top_left==popup_style.corner_radius_bottom_left and popup_style.corner_radius_top_left>0,"popup corners consistent")
 check(app.editor_dialog.transparent_bg,"dialog viewport transparent for rounded frame")
 app._close_editor();await settle()
 app.queue_free();await settle()
 for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute("user://state.json"+suffix)
 print("SELECTOR_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
