extends SceneTree
const Reorder=preload("res://scripts/reorder_handle.gd")
var failures:=0
var checks:=0
func _init()->void:
 if FileAccess.file_exists("user://state.json"):quit(2);return
 call_deferred("run")
func settle()->void:
 for i in range(5):await process_frame
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func handles(node:Node)->Array:
 var result:=[]
 for child in node.get_children():
  if child.get_script()==Reorder:result.append(child)
  result.append_array(handles(child))
 return result
func mouse(pos:Vector2,down:bool)->void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=pos;root.push_input(e,true)
func motion(pos:Vector2)->void:
 var e:=InputEventMouseMotion.new();e.position=pos;e.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(e,true)
func key(code:Key,alt:bool=false)->void:
 var e:=InputEventKey.new();e.pressed=true;e.keycode=code;e.alt_pressed=alt;root.push_input(e,true)
func run()->void:
 root.size=Vector2i(480,800)
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 app._open_editor();await settle()
 var original=app.preset.slices.map(func(s):return s.id)
 var h=handles(app.editor)
 h[0].grab_focus();key(KEY_DOWN,true);await settle()
 check(app.preset.slices[1].id==original[0],"real AltDown reorders item by ID")
 var focused=root.gui_get_focus_owner()
 check(focused!=null and focused.get_script()==Reorder and focused.index==1,"keyboard focus follows moved row after rebuild")
 key(KEY_DOWN,true);await settle()
 check(app.preset.slices[2].id==original[0],"consecutive keyboard reorder works after rebuilding")
 h=handles(app.editor)
 var before=app.preset.slices.map(func(s):return s.id)
 var start:Vector2=h[0].global_position+h[0].size/2
 mouse(start,true);motion(start+Vector2(0,2));mouse(start+Vector2(0,2),false);await settle()
 check(app.preset.slices.map(func(s):return s.id)==before,"tiny native mouse movement does not reorder")
 h=handles(app.editor);start=h[0].global_position+h[0].size/2
 var target:Vector2=h[1].global_position+h[1].size/2+Vector2(0,8)
 mouse(start,true);motion(target);await settle();key(KEY_ESCAPE);await settle()
 check(app.preset.slices.map(func(s):return s.id)==before,"Escape cancels native mouse drag without mutation")
 check(app.editor_dialog.visible,"Escape cancels drag without closing editor")
 mouse(target,false);await settle()
 h=handles(app.editor);start=h[0].global_position+h[0].size/2;target=h[1].global_position+h[1].size/2+Vector2(0,8)
 mouse(start,true);motion(target);mouse(target,false);await settle()
 check(app.preset.slices[1].id==before[0],"native mouse drop mutates once at final index")
 check(not app.busy and app.preset.history.is_empty(),"row drag never spins wheel or records result")
 app._close_editor();app._new_preset();app._new_preset();app._preset_manager();await settle()
 var preset_ids=app.data.presets.map(func(p):return p.id)
 h=handles(app.manager_dialog)
 h[0].grab_focus();key(KEY_DOWN,true);await settle()
 check(app.data.presets[1].id==preset_ids[0],"manager keyboard reorder uses preset IDs")
 focused=root.gui_get_focus_owner()
 check(focused!=null and focused.get_script()==Reorder and focused.index==1,"manager keyboard focus follows reordered preset")
 app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("REORDER_INTEGRATION_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
