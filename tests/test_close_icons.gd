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
func move(p:Vector2)->void:
 var e:=InputEventMouseMotion.new();e.position=p;root.push_input(e,true)
func mouse(p:Vector2,down:bool)->void:
 var e:=InputEventMouseButton.new();e.position=p;e.pressed=down;e.button_index=MOUSE_BUTTON_LEFT;root.push_input(e,true)
func bbox(crop:Image,red:bool)->Rect2i:
 var lo:=Vector2i(999,999);var hi:=Vector2i(-1,-1)
 var bg:=crop.get_pixel(8,8)
 var peak:=0.0
 for y in range(8,crop.get_height()-8):
  for x in range(8,crop.get_width()-8):
   var c:=crop.get_pixel(x,y)
   peak=maxf(peak,bg.r-c.r)

 for y in range(8,crop.get_height()-8):
  for x in range(8,crop.get_width()-8):
   var c:=crop.get_pixel(x,y)
   var ink:bool=c.r>c.g*1.5 and c.r>c.b*1.35 and c.g<.5 if red else bg.r-c.r>maxf(.01,peak*.25)
   if ink:lo=lo.min(Vector2i(x,y));hi=hi.max(Vector2i(x,y))
 return Rect2i(lo,hi-lo+Vector2i.ONE) if hi.x>=0 else Rect2i()
func states(b:Button,label:String,red:bool,sheet:Image,row:int)->void:
 var connections=b.pressed.get_connections()
 for connection in connections:b.pressed.disconnect(connection.callable)
 var original_size:=b.size;var reference:=Rect2i();var margin:Vector2=b.get_theme_stylebox("normal").get_minimum_size()
 var names=["normal","hover","pressed","focus","disabled"]
 for i in range(names.size()):
  var state:String=names[i]
  b.disabled=false;b.release_focus();move(Vector2(950,790));await settle()
  var center:=b.get_global_rect().get_center()
  if state=="hover":move(center)
  if state=="pressed":move(center);mouse(center,true)
  if state=="focus":b.grab_focus()
  if state=="disabled":b.disabled=true;move(center)
  await settle()
  var crop:=root.get_texture().get_image().get_region(Rect2i(b.get_global_rect()))
  var rect:=bbox(crop,red)
  if i==0:reference=rect
  check(rect.has_area(),label+" "+state+" colored glyph visible")
  check(rect.size==reference.size,label+" "+state+" constant glyph bbox")
  var centering_error:=Vector2(rect.position)+Vector2(rect.size)*.5-b.size*.5
  check((absf(centering_error.x)<=.5 and absf(centering_error.y)<=.5) if red else centering_error.length()<=1.5,label+" "+state+" glyph centered")
  check(b.size==original_size and b.get_theme_stylebox(state).get_minimum_size()==margin,label+" "+state+" constant hitarea and padding")
  sheet.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(i*70,row*70))
  mouse(Vector2(950,790),false);await settle()
 b.disabled=false
 for connection in connections:b.pressed.connect(connection.callable)
func all(n:Node)->Array:
 var a=[]
 for c in n.get_children():
  if c is Button:a.append(c)
  a.append_array(all(c))
 return a
func run()->void:
 root.size=Vector2i(960,800)
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 var sheet:=Image.create(350,840,false,Image.FORMAT_RGBA8);sheet.fill(Color.WHITE)
 var modes=["editor","manager","global","history","add","color","confirm","message"]
 for i in range(modes.size()):
  var kind:String=modes[i]
  match kind:
   "editor":app._open_editor()
   "manager":app._preset_manager()
   "global":app._settings()
   "history":app._history()
   "add":app._add_preset_dialog()
   "color":app._pick_color(app.preset.slices[0])
   "confirm":app._confirm("확인","테스트",func():pass)
   "message":app._message("알림","테스트")
  await settle()
  var layer=app._top_layer();var b:Button=layer._close
  await states(b,kind,true,sheet,i)
  var center:=b.get_global_rect().get_center();move(center);mouse(center,true);mouse(center,false);await settle()
  check(not is_instance_valid(layer) or not layer.visible,kind+" real close click dismisses layer")
 var row:=8
 for b in all(app):
  if b.is_visible_in_tree() and b.icon!=null and b.tooltip_text in ["설정","라운드 복원","룰렛 편집","결과 기록"]:
   await states(b,b.tooltip_text,false,sheet,row);row+=1
 sheet.save_png("/tmp/close-icon-state-matrix.png")
 app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("CLOSE_ICON_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
