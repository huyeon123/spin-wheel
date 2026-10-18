extends SceneTree
const Handle=preload("res://scripts/reorder_handle.gd")
var checks:=0
var failures:=0
func _init()->void:
 if FileAccess.file_exists("user://state.json"):quit(2);return
 call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func settle()->void:
 for i in range(5):await process_frame
func handles(n:Node)->Array:
 var a=[]
 for c in n.get_children():
  if c.get_script()==Handle:a.append(c)
  a.append_array(handles(c))
 return a
func trace(app,host,label:String)->void:
 var h=handles(host)[0]
 var start:Vector2=h.global_position+h.size/2
 var before=JSON.stringify(app.data)
 var old_rows=h.list_container.get_children().map(func(c):return c.get_instance_id())
 h._begin(start,-1)
 var previous:=0.0;var total:=0;var max_jump:=0.0;var min_jump:=100.0
 for y in range(int(start.y)+9,int(h.scroll.get_global_rect().end.y)-45):
  h._move(Vector2(start.x,y))
  var gy:float=h._visual.ghost.position.y
  if total>0:
   var jump=gy-previous;max_jump=maxf(max_jump,absf(jump));min_jump=minf(min_jump,jump)
  previous=gy;total+=1
 check(max_jump<=1.001 and min_jump>=.999,label+" ghost moves exactly1px per1px cursor")
 print(label," samples=",total," max_jump=",max_jump," min_jump=",min_jump)
 var stationary=h._visual.ghost.position
 for delta in [1.0/30,1.0/60,1.0/120,1.0/240]:h._process(delta)
 check(h._visual.ghost.position==stationary,label+" ghost position independent of frame duration")
 check(JSON.stringify(app.data)==before,label+" movement does not mutate model")
 check(h.list_container.get_children().map(func(c):return c.get_instance_id())==old_rows,label+" movement never rebuilds rows")
 h._cancel()
func run()->void:
 root.size=Vector2i(480,800)
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 app._open_editor();await settle();trace(app,app.editor,"editor")
 app._close_editor();app._new_preset();app._new_preset();app._preset_manager();await settle();trace(app,app.manager_dialog,"manager")
 app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("DRAG_CONTINUITY_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
