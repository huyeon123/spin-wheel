extends SceneTree
var checks:=0
var failures:=0
func _init()->void:
 if FileAccess.file_exists("user://state.json"):quit(2);return
 call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func settle()->void:
 for i in range(6):await process_frame
func fits(app,layer,caption:String)->void:
 var r:Rect2=layer.card.get_global_rect()
 check(r.position.x>=0 and r.position.y>=0 and r.end.x<=app.size.x+1 and r.end.y<=app.size.y+1,caption+" card fits viewport")
 var x:Rect2=layer._close.get_global_rect()
 check(x.position.x>=r.position.x and x.position.y>=r.position.y and x.end.x<=r.end.x and x.end.y<=r.end.y,caption+" top close remains visible")
 check(layer.content.get_combined_minimum_size().x<=layer._scroll.size.x+1,caption+" no horizontal content clipping")
func run()->void:
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 for size in [Vector2i(480,800),Vector2i(390,700),Vector2i(360,560),Vector2i(320,480)]:
  root.size=size;await settle()
  check(app.spin_button.get_global_rect().end.y<=app.size.y+1,"spin reachable without scroll at "+str(size))
  app._open_editor();await settle();fits(app,app.editor_dialog,"editor "+str(size));app._close_top_layer();await settle()
  app._preset_manager();await settle();fits(app,app.manager_dialog,"manager "+str(size));app._close_top_layer();await settle()
  app._settings();await settle();fits(app,app._top_layer(),"global "+str(size));app._close_top_layer();await settle()
  app._history();await settle();fits(app,app.history_dialog,"history "+str(size));app._close_top_layer();await settle()
  app._add_preset_dialog();await settle();fits(app,app._top_layer(),"add "+str(size));app._close_top_layer();await settle()
  app._open_editor();await settle();app._pick_color(app.preset.slices[0]);await settle();fits(app,app._top_layer(),"color "+str(size));app._close_top_layer();await settle();app._close_top_layer();await settle()
 app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("NARROW_LAYER_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
