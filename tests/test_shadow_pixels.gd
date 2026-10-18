extends SceneTree
var checks:=0
var failures:=0
func _init()->void:
 # Legacy behavior fixtures explicitly opt out; real timing is tested separately.
 load("res://scripts/wheel_layer.gd").reduced_motion = true
 if DisplayServer.get_name()=="headless":quit(2);return
 if FileAccess.file_exists("user://state.json"):quit(2);return
 call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func settle()->void:
 for i in range(4):await process_frame
func sample(app)->Array:
 var frame:=root.get_texture().get_image()
 var center:Vector2=app.wheel_shadow.global_position+app.wheel_shadow.size/2
 var radius:float=minf(app.wheel_shadow.size.x,app.wheel_shadow.size.y)/2-12
 var colors=[]
 for degrees in [20,45,70,110,135,160,200,225,250,290,315,340]:
  var p:=center+Vector2.from_angle(deg_to_rad(degrees))*(radius+8)
  p=app.get_viewport().get_final_transform()*p
  colors.append(frame.get_pixel(roundi(p.x),roundi(p.y)))
 return colors
func equal_samples(a:Array,b:Array)->bool:
 for i in range(a.size()):
  if Vector3(a[i].r,a[i].g,a[i].b).distance_to(Vector3(b[i].r,b[i].g,b[i].b))>.008:return false
 return true
func geometry(app,caption:String)->void:
 check(app.wheel_shadow.get_parent()==app.wheel.get_parent() and app.wheel_shadow.get_index()<app.wheel.get_index(),caption+" shadow behind rotating wheel sibling")
 check(app.wheel_shadow.rotation==0 and app.wheel_shadow.size==app.wheel.size and app.wheel_shadow.position==app.wheel.position,caption+" shadow screen offset and center alignment fixed")
func run()->void:
 root.size=Vector2i(960,800)
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 check(not app.wheel.draw_shadow,"rotating wheel does not duplicate shadow")
 var initial=sample(app)
 check((initial[2].r+initial[3].r)/2 < (initial[8].r+initial[9].r)/2-.015,"shadow visibly extends below rather than above wheel")
 for angle in [0.0,PI/2,PI,PI*1.5]:
  app.wheel.rotation=angle;await settle();geometry(app,"angle "+str(angle))
  check(equal_samples(initial,sample(app)),"exterior shadow pixels stay fixed at angle "+str(angle))
 app.data.settings.sound=false;app.data.settings.duration=1.0
 for direction in [1.0,-1.0]:
  var center:Vector2=app.wheel.get_parent().global_position+app.wheel.size/2
  var radius:float=minf(app.wheel.size.x,app.wheel.size.y)*.3
  app._begin_drag(center+Vector2(radius,0),-1)
  for step in range(1,5):
   app.drag_last_time-=.025
   app._move_drag(center+Vector2.from_angle(direction*.15*step)*radius)
  await settle()
  geometry(app,"drag "+str(direction));check(equal_samples(initial,sample(app)),"shadow pixels fixed during drag "+str(direction))
  app._end_drag()
  check(app.busy and not app.dragging,"qualified drag releases into coast "+str(direction))
  await create_timer(.4).timeout
  geometry(app,"coast "+str(direction));check(equal_samples(initial,sample(app)),"shadow pixels fixed during coast "+str(direction))
  await create_timer(.75).timeout
 for physical in [Vector2i(480,800),Vector2i(390,700)]:
  root.size=physical;await settle();geometry(app,"resize "+str(physical))
  var baseline=sample(app)
  app.wheel.rotation+=PI;await settle();check(equal_samples(baseline,sample(app)),"shadow pixels fixed after resize "+str(physical))
 root.get_texture().get_image().save_png("/tmp/fixed-shadow.png")
 app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("SHADOW_PIXEL_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
