extends SceneTree
var checks:=0
var failures:=0
func _init()->void:
 # Legacy behavior fixtures explicitly opt out; real timing is tested separately.
 load("res://scripts/wheel_layer.gd").reduced_motion = true
 if FileAccess.file_exists("user://state.json"):quit(2);return
 call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func settle()->void:
 for i in range(6):await process_frame
func tab(shift:=false)->void:
 var event=InputEventKey.new();event.keycode=KEY_TAB;event.pressed=true;event.shift_pressed=shift;root.push_input(event,true)
 event=InputEventKey.new();event.keycode=KEY_TAB;event.pressed=false;event.shift_pressed=shift;root.push_input(event,true)
func run()->void:
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 for route in ["direct","reopen","manager"]:
  if route=="manager":app._preset_manager();await settle();app._manager_edit(app.preset.id)
  else:app._open_editor()
  await settle()
  check(root.gui_get_focus_owner()==app.editor_dialog.card,route+" editor opens with neutral focus")
  check(not root.gui_get_focus_owner() is LineEdit,route+" no text input auto-focus")
  check(app.editor_dialog._scroll.scroll_vertical==0,route+" editor opens at top")
  tab();await settle()
  check(root.gui_get_focus_owner()==app.editor_dialog._close,route+" real Tab enters close control")
  app.editor_dialog.card.grab_focus();tab(true);await settle()
  check(app.editor_dialog.card.is_ancestor_of(root.gui_get_focus_owner()) and root.gui_get_focus_owner()!=app.editor_dialog.card,route+" reverse Tab remains in modal")
  var input:LineEdit=app.editor.find_children("*","LineEdit",true,false)[0]
  input.grab_focus();await settle()
  check(root.gui_get_focus_owner()==input,route+" explicit input focus still works")
  app._message("테스트","중첩 메시지");await settle();app._close_top_layer();await settle()
  check(root.gui_get_focus_owner()==input,route+" nested dialog restores explicit input focus")
  app._close_editor();await settle()
 app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("EDITOR_FOCUS_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
