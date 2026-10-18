extends SceneTree
const Safe=preload("res://scripts/safe_layout.gd")
var checks:=0
var failures:=0
func _init()->void:
 load("res://scripts/wheel_layer.gd").reduced_motion=true
 if FileAccess.file_exists("user://state.json"):quit(2);return
 call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func settle()->void:
 for i in range(8):await process_frame
func inside(a:Rect2,b:Rect2)->bool:
 return a.position.x>=b.position.x-.1 and a.position.y>=b.position.y-.1 and a.end.x<=b.end.x+.1 and a.end.y<=b.end.y+.1
func approx(a:Rect2,b:Rect2)->bool:
 return a.position.distance_to(b.position)<.01 and a.size.distance_to(b.size)<.01
func run()->void:
 for value in [true,1]:check(Safe.java_truth(value),"JNI integer/boolean true normalized without invalid comparison")
 for value in [false,0,null]:check(not Safe.java_truth(value),"JNI false/null safely normalized")
 var client=Rect2(0,0,720,1560)
 var native=Rect2(0,0,1080,2340)
 var engine_cutout=Rect2(0,90,1080,2250)
 var sample={"bounds":native,"render_bounds":native,"insets":Vector4(0,90,0,72),"ime_bottom":0.0}
 check(approx(Safe.native_to_client(client,native,Rect2(0,90,1080,2178)),Rect2(0,60,720,1452)),"native pixels map into differently sized render buffer")
 check(approx(Safe.android_safe_client(client,engine_cutout,sample),Rect2(0,60,720,1452)),"mismatched decor/buffer retains camera and gesture insets")
 sample.ime_bottom=900.0
 check(approx(Safe.android_safe_client(client,engine_cutout,sample),Rect2(0,60,720,900)),"native IME alone shrinks safe area even with no Godot keyboard event")
 sample.render_bounds=Rect2(0,0,1080,1440)
 check(approx(Safe.android_safe_client(Rect2(0,0,720,960),engine_cutout,sample),Rect2(0,60,720,900)),"already resized render view applies keyboard exactly once")
 sample.ime_bottom=0.0;sample.render_bounds=native
 check(approx(Safe.android_safe_client(client,engine_cutout,sample),Rect2(0,60,720,1452)),"dismissed native IME restores full safe area")
 sample.render_bounds=Rect2(0,90,1080,2178)
 check(approx(Safe.android_safe_client(Rect2(0,0,720,1452),engine_cutout,sample),Rect2(0,0,720,1452)),"render-view origin already below camera avoids doubled top inset")
 sample.render_bounds=native
 for bottom in [72.0,144.0]:
  sample.insets=Vector4(0,90,0,bottom)
  var safe=Safe.android_safe_client(client,engine_cutout,sample)
  check(is_equal_approx(safe.end.y,(2340-bottom)*2.0/3.0),"gesture and three-button navigation reserve actual native bottom")
 sample.insets=Vector4(0,120,0,72)
 check(is_equal_approx(Safe.android_safe_client(client,engine_cutout,sample).position.y,80.0),"visible status bar raises safe top from actual measurement")
 sample.insets=Vector4(0,90,0,72)
 var mobile=Safe.compute_main(Rect2(0,0,480,1040),Rect2(0,40,480,968),0.0,true)
 check(is_equal_approx(mobile.header.position.y,52.0),"mobile header uses compact measured-safe top spacing")
 check(is_equal_approx(mobile.actions.end.y,976.0),"mobile bottom actions retain32 logical pixels above measured nav boundary")

 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle();app.preset.duration_override=6.0
 root.gui_embed_subwindows=true
 root.size=Vector2i(1080,2340);await settle()
 var actual=Safe.control_to_client_transform(app)
 check(is_equal_approx(actual.x.x,2.25) and is_equal_approx(actual.y.y,2.25),"actual embedded Android-style root retains viewport stretch")
 check(is_equal_approx(app.get_screen_transform().x.x,1.0),"fixture reproduces Godot embedded get_screen_transform scale omission")
 check(approx(Safe.screen_to_local(Rect2(Vector2.ZERO,app.size),actual,Rect2(Vector2(0,90)+Vector2(DisplayServer.window_get_position()),Vector2(1080,2178))),Rect2(0,40,480,968)),"actual runtime transform places cutout and navigation correctly")
 check(approx(Safe.screen_to_local(Rect2(Vector2.ZERO,app.size),actual,Rect2(Vector2(0,90)+Vector2(DisplayServer.window_get_position()),Vector2(1080,1350))),Rect2(0,40,480,600)),"actual embedded transform places keyboard boundary inside logical viewport")
 for sizes in [[Vector2i(1080,2340),Vector2i(1080,1260)],[Vector2i(390,844),Vector2i(390,460)],[Vector2i(320,480),Vector2i(320,300)]]:
  root.size=sizes[0];await settle();app._open_editor();await settle()
  var layer=app.editor_dialog;var original=layer.card.get_global_rect();var original_pixels=original.size.y*root.get_final_transform().y.y
  check(root.gui_get_focus_owner()==layer.card,"opening editor remains neutral and does not request keyboard")
  var field:Control
  for node in app.editor.find_children("*","LineEdit",true,false):
   if node.get_meta("duration_input",false):field=node
  field.grab_focus();await settle()
  root.size=sizes[1];await settle()
  var shortened=layer.card.get_global_rect()
  check(shortened.size.y*root.get_final_transform().y.y<original_pixels,"keyboard-sized client reduces actual rendered modal height")
  check(inside(shortened,Rect2(Vector2.ZERO,app.size)),"shrunk modal stays inside available client")
  check(inside(field.get_global_rect(),layer._scroll.get_global_rect()),"focused bottom field scrolls above keyboard-sized client bottom")
  check(inside(layer._close.get_global_rect(),shortened),"top close remains reachable while keyboard open")
  root.size=sizes[0];await settle()
  check(approx(layer.card.get_global_rect(),original),"keyboard dismissal restores original card bounds")
  app._close_editor();await settle();app._open_editor();await settle()
  check(root.gui_get_focus_owner()==layer.card,"close/reopen after keyboard leaves neutral initial focus")
  app._close_editor();await settle()
 app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("ANDROID_INSETS_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
