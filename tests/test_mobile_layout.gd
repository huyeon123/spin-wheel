extends SceneTree
const Safe=preload("res://scripts/safe_layout.gd")
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
func approx(a:Rect2,b:Rect2)->bool:
 return a.position.distance_to(b.position)<.01 and a.size.distance_to(b.size)<.01
func inside(inner:Rect2,outer:Rect2)->bool:
 return inner.position.x>=outer.position.x-.1 and inner.position.y>=outer.position.y-.1 and inner.end.x<=outer.end.x+.1 and inner.end.y<=outer.end.y+.1
func run()->void:
 var local=Rect2(0,0,480,1040)
 var transform=Transform2D(Vector2(2.25,0),Vector2(0,2.25),Vector2.ZERO)
 var mapped=Safe.screen_to_local(local,transform,Rect2(0,90,1080,2187))
 check(approx(mapped,Rect2(0,40,480,972)),"Galaxy pixel insets convert to logical units")
 transform.origin=Vector2(0,90)
 check(approx(Safe.screen_to_local(Rect2(0,0,480,972),transform,Rect2(0,90,1080,2187)),Rect2(0,0,480,972)),"already inset viewport avoids double top padding")
 transform.origin=Vector2(-1200,80)
 check(approx(Safe.screen_to_local(local,transform,Rect2(-1200,170,1080,2187)),Rect2(0,40,480,972)),"nonzero and negative screen origins map correctly")
 transform.origin=Vector2.ZERO
 check(approx(Safe.screen_to_local(Rect2(0,0,480,600),transform,Rect2(0,90,1080,2187)),Rect2(0,40,480,560)),"keyboard-reduced viewport intersects full screen safe area")
 var baseline=Rect2(0,0,1080,2340)
 var keyboard_safe=Safe.exclude_keyboard(Rect2(0,90,1080,2187),baseline,900)
 check(approx(keyboard_safe,Rect2(0,90,1080,1350)),"overlay keyboard excludes bottom in physical pixels")
 check(approx(Safe.exclude_keyboard(Rect2(0,90,1080,1350),baseline,900),keyboard_safe),"already resized keyboard safe area is not subtracted twice")
 check(approx(Safe.screen_to_local(Rect2(0,0,480,640),transform,keyboard_safe),Rect2(0,40,480,600)),"keyboard pixels map through stretch once")
 check(approx(Safe.exclude_keyboard(Rect2(0,90,1080,2187),baseline,0),Rect2(0,90,1080,2187)),"keyboard dismissal restores full safe region")
 var cases=[Rect2(0,0,480,800),Rect2(0,40,480,972),Rect2(12,36,456,724),Rect2(0,24,480,456),Rect2(0,20,320,400)]
 for safe in cases:
  var bounds=Rect2(Vector2.ZERO,Vector2(safe.end.x,safe.end.y+20))
  var layout=Safe.compute_main(bounds,safe,0)
  for key in ["header","result","wheel","spin","actions"]:
   check(layout.has(key) and inside(layout[key],safe),str(key)+" fits safe region "+str(safe))
  check(layout.wheel.end.y<=layout.spin.position.y+.1,"wheel does not overlap spin")
  check(absf(layout.wheel.size.x-layout.wheel.size.y)<.1,"wheel remains circular")
  check(layout.header.end.y<=layout.wheel.position.y+.1,"header does not overlap wheel")
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 for physical in [Vector2i(480,800),Vector2i(1080,2340),Vector2i(390,844),Vector2i(360,640),Vector2i(320,480),Vector2i(480,400)]:
  root.size=physical;await settle()
  check(inside(app.main_header.get_global_rect(),app.safe_bounds),"actual header safe "+str(physical))
  check(inside(app.spin_button.get_global_rect(),app.safe_bounds),"actual spin safe "+str(physical))
  check(inside(app.action_controls.get_global_rect(),app.safe_bounds),"actual bottom actions safe "+str(physical))
  for action in app.action_controls.get_children():
   check(inside(action.get_global_rect(),app.safe_bounds),"actual action button safe "+str(physical))
  check(app.wheel.size.x>0 and app.wheel.size.y>0,"actual wheel retains area "+str(physical))
 app.preset.duration_override=6.5;app._open_editor();await settle()
 var focus:Control
 for child in app.editor.find_children("*","LineEdit",true,false):
  if child.get_meta("duration_input",false):focus=child
 focus.grab_focus();await settle()
 app.editor_dialog.layout_card(Vector2i(480,360));await settle()
 check(inside(focus.get_global_rect(),app.editor_dialog._scroll.get_global_rect()),"focused bottom duration remains scrolled into view after card shrink")
 check(app.editor_dialog._close.get_global_rect().end.y<=app.editor_dialog.card.get_global_rect().end.y,"top close retained during keyboard-sized shrink")
 app._close_editor();await settle()
 app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("MOBILE_LAYOUT_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
