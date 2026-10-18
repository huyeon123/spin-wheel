extends SceneTree
const Layer=preload("res://scripts/wheel_layer.gd")
var checks:=0
var failures:=0
func _init()->void:
 if FileAccess.file_exists("user://state.json"):quit(2);return
 Layer.reduced_motion=false
 call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func settle()->void:
 await create_timer(.26).timeout
func run()->void:
 root.size=Vector2i(480,800)
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 app.main_selector.grab_focus();app._open_editor();var editor=app.editor_dialog
 check(editor.visible and editor.modulate.a<.1,"open begins transparent while modal is active")
 await create_timer(.07).timeout
 check(editor.modulate.a>0 and editor.modulate.a<1 and editor._motion_offset>0,"real entrance interpolates alpha and position")
 check(root.gui_get_focus_owner()==editor.card,"entrance avoids text focus and keyboard")
 app._spin();check(not app.busy,"entering layer blocks background spin")
 await settle()
 check(is_equal_approx(editor.modulate.a,1) and is_zero_approx(editor._motion_offset),"entrance settles exactly")
 check(editor.card.get_global_rect().position.y>=app.safe_bounds.position.y,"settled card remains in safe bounds")
 var count=[0];editor.dismiss(func():count[0]+=1);editor.dismiss(func():count[0]+=10)
 await create_timer(.05).timeout
 check(editor.visible and editor._closing and editor._exit_blocker.visible,"exit remains visible and blocks interaction")
 check(count[0]==0,"close callback not delivered before exit")
 await settle();check(not editor.visible and count[0]==1,"reentrant close delivers once")
 check(root.gui_get_focus_owner()==app.main_selector,"close restores opener after exit")
 app._open_editor();await create_timer(.03).timeout;editor.dismiss(func():count[0]+=10);await create_timer(.03).timeout;editor.popup_centered()
 await settle();check(editor.visible and count[0]==1 and not editor._closing,"reopen cancels stale exit callback")
 check(app._top_layer()==editor,"reopened editor owns top stack")
 app._message("Nested","Dialog");await settle();var nested=app._top_layer()
 check(nested!=editor and editor.visible,"nested layer leaves parent visible")
 app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 await create_timer(.04).timeout
 check(nested.visible and nested._closing,"back animates top layer only")
 await settle();check(app._top_layer()==editor and editor.visible,"back restores underlying editor")
 var key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;root.push_input(key,true);await settle()
 check(not editor.visible,"Escape finishes editor exit")
 app._open_editor();await settle();editor.dismiss();app._settings();await settle()
 var settings=app._top_layer();check(settings!=editor and settings.is_ancestor_of(root.gui_get_focus_owner()),"old close cannot steal focus from newer settings")
 app._close_top_layer();await settle()
 var drop=Layer.new();drop.is_dropdown=true;drop.dropdown_anchor=Rect2(20,20,200,40);app.add_child(drop);drop.add_content(Label.new());drop.popup_centered();await settle()
 var outside=InputEventScreenTouch.new();outside.index=0;outside.position=Vector2(450,750);outside.pressed=true;root.push_input(outside,true);await settle()
 check(not drop.visible,"touch outside dropdown uses animated close")
 drop.queue_free();await settle()
 var selector=load("res://scripts/wheel_select.gd").new();app.add_child(selector);selector.add_item("One");selector.add_item("Two");selector.size=Vector2(200,48)
 var selections=[0];selector.item_selected.connect(func(_i):selections[0]+=1)
 selector.open_choices();await settle();selector.choose(1)
 check(selector.selected==0 and selections[0]==0,"selector change waits until exit completion")
 selector.open_choices();await settle()
 check(selector.popup.visible and selector.selected==0 and selections[0]==0,"reopen cancels stale selector choice")
 selector.choose(1);selector.choose(0);await settle()
 check(selector.selected==1 and selections[0]==1,"repeated selector choice commits first choice once")
 selector.queue_free();await settle()
 Layer.reduced_motion=true;app._open_editor();await process_frame;await process_frame
 check(editor.modulate.a==1 and editor._motion_offset==0,"explicit reduced motion removes movement")
 app._close_editor();for i in range(5):await process_frame
 check(not editor.visible,"reduced motion keeps deferred close semantics")
 app.wheel_audio.stop();app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("OVERLAY_ANIMATION_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
