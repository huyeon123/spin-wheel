extends SceneTree
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
func find_select(node:Node)->Node:
 for child in node.get_children():
  if child.get_script()==load("res://scripts/wheel_select.gd"):return child
  var found=find_select(child)
  if found!=null:return found
 return null
func run()->void:
 root.size=Vector2i(480,800)
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 app._preset_settings();await settle()
 var parent_layer=app._top_layer()
 var select=find_select(parent_layer)
 check(select!=null,"override retains custom selector")
 select.open_choices();await settle()
 var drop=select.popup
 check(drop is Control and not drop is Window,"selector is in-app Control")
 check(drop.is_dropdown and not drop.show_footer,"compact dropdown without header or footer")
 check(absf(drop.card.size.x-select.size.x)<=1,"dropdown matches field width")
 check(drop.card.global_position.x>=0 and drop.card.get_global_rect().end.x<=app.size.x,"dropdown fits viewport")
 app._spin();check(not app.busy,"dropdown blocks spin")
 for down in [true,false]:
  var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=Vector2(2,2);root.push_input(e,true)
 await settle()
 check(app._top_layer()==parent_layer,"outside mouse dismisses dropdown only")
 select.open_choices();await settle()
 for down in [true,false]:
  var e:=InputEventScreenTouch.new();e.index=0;e.pressed=down;e.position=Vector2(2,2);root.push_input(e,true)
 await settle()
 check(app._top_layer()==parent_layer,"outside touch dismisses dropdown only")
 select.open_choices();await settle();select.choose(2);await settle()
 check(app.preset.remove_override==true,"deferred selection saves override without detaching viewport")
 app._close_top_layer();await settle()
 check(not app._has_layer(),"back closes last layer")
 app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("SELECTOR_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
