extends SceneTree
var checks:=0
var failures:=0
func _init()->void:
 if DisplayServer.get_name()=="headless":quit(2);return
 call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func settle()->void:
 for i in range(5):await process_frame
func run()->void:
 root.size=Vector2i(960,800)
 var canvas:=ColorRect.new();canvas.color=Color("#f6f6f4");canvas.size=Vector2(960,800);root.add_child(canvas)
 var wheel=load("res://scripts/wheel_canvas.gd").new();root.add_child(wheel);wheel.position=Vector2(200,100);wheel.size=Vector2(500,500);wheel.show_labels=false
 for i in range(4):wheel.slices.append({"name":"","color":"#203040","weight":1.0})
 wheel.queue_redraw();await settle()
 for angle in [0.0,.4,1.2]:
  wheel.rotation=angle;await settle()
  var frame=root.get_texture().get_image();var strengths=[]
  for seam in range(4):
   var direction=Vector2.from_angle(-PI/2+seam*PI/2)
   var center:Vector2=wheel.get_global_transform()*(wheel.size/2+direction*142.8)
   var perpendicular=direction.rotated(angle+PI/2)
   var strength:=0.0
   for offset in range(-5,6):
    var point:Vector2=center+perpendicular*offset
    var pixel=frame.get_pixel(roundi(point.x),roundi(point.y))
    strength+=maxf(0,pixel.r-32.0/255)
   strengths.append(strength)
  var minimum:float=strengths.min();var maximum:float=strengths.max()
  print("WHEEL_SEAMS angle=",angle," strengths=",strengths," ratio=",minimum/maximum)
  check(minimum/maximum>.65,"all radial separators have comparable visible coverage at rotation "+str(angle))
  frame.save_png("/tmp/wheel-seams-"+str(angle)+".png")
 print("WHEEL_PIXEL_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
