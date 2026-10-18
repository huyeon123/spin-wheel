extends SceneTree
var checks := 0
var failures := 0
func _init() -> void:
 if FileAccess.file_exists("user://state.json") or FileAccess.file_exists("user://state.json.bak"):
  push_error("Gesture tests require fresh isolated user data."); quit(2); return
 call_deferred("run")
func check(ok: bool, text: String) -> void:
 checks += 1
 if not ok: failures += 1; push_error(text)
func settle() -> void:
 for i in range(5): await process_frame
func point(app: Control, angle: float, scale: float = .7) -> Vector2:
 var holder = app.wheel.get_parent()
 var radius = minf(holder.size.x, holder.size.y) / 2 - 12
 return holder.get_global_transform_with_canvas() * (holder.size / 2 + Vector2.from_angle(angle) * radius * scale)
func touch(app: Control, index: int, pressed: bool, pos: Vector2, canceled: bool = false) -> void:
 var e := InputEventScreenTouch.new(); e.index=index; e.pressed=pressed; e.position=pos; e.canceled=canceled; app._input(e)
func mouse(app: Control, pressed: bool, pos: Vector2, emulated: bool = false) -> void:
 var e := InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=pressed; e.position=pos
 if emulated: e.device=InputEvent.DEVICE_ID_EMULATION
 app._input(e)
func move(app: Control, angle: float, dt: float = .1) -> void:
 app.drag_last_time = Time.get_ticks_usec() / 1000000.0 - dt
 app._move_drag(point(app, angle))
func winner_at_pointer(app: Control) -> String:
 var total := 0.0
 for s in app.wheel.slices: total += float(s.weight)
 var angle := fposmod(-app.wheel.rotation, TAU)
 var cumulative := 0.0
 for s in app.wheel.slices:
  cumulative += TAU * float(s.weight) / total
  if angle < cumulative: return s.name
 return ""
func run() -> void:
 root.size=Vector2i(480,800)
 var app=load("res://main.tscn").instantiate(); root.add_child(app); await settle()
 var pointer: TextureRect
 for child in app.wheel.get_parent().get_children():
  if child is TextureRect: pointer=child
 check(pointer != null and is_equal_approx(pointer.global_position.x + pointer.size.x/2, app.wheel.get_parent().global_position.x + app.wheel.get_parent().size.x/2),"visible SVG pointer aligned to wheel angular origin")
 check(app.wheel._label_color(Color.BLACK)==Color.WHITE,"dark custom slices use white labels")
 check(app.wheel._label_color(Color.WHITE)!=Color.WHITE,"light custom slices use dark labels")
 app.data.settings.duration=1.0; app.data.settings.sound=false
 for i in range(app.preset.slices.size()): app.preset.slices[i].weight = float(i+1)
 app._definition_changed()
 var p=point(app,0)
 app._begin_drag(point(app,0,0),-1)
 check(not app.dragging and not app.busy,"center tap ignored")
 app._begin_drag(point(app,0,1.5),-1)
 check(not app.dragging,"outside wheel ignored")
 mouse(app,true,p,true)
 check(not app.dragging,"synthetic mouse ignored")
 mouse(app,true,p)
 check(app.dragging and app.busy and app.main_selector.disabled,"mouse drag locks controls")
 app._settings_hub(); app._new_preset(); app._spin()
 check(not app._has_layer() and app.data.presets.size()==1 and app.preset.history.is_empty(),"drag prevents edits and parallel spins")
 move(app,.05)
 mouse(app,false,point(app,.05))
 check(not app.busy and app.preset.history.is_empty(),"tiny gesture does not select winner")
 touch(app,0,true,p)
 touch(app,1,true,point(app,PI))
 check(app.drag_pointer==0,"second touch cannot replace first")
 var rotation_before: float=app.wheel.rotation
 var other:=InputEventScreenDrag.new(); other.index=1; other.position=point(app,PI/2); app._input(other)
 check(app.wheel.rotation==rotation_before,"second touch movement ignored")
 touch(app,1,false,p)
 check(app.dragging,"second touch release ignored")
 touch(app,0,false,p,true)
 check(not app.dragging and not app.busy and app.preset.history.is_empty(),"touch cancellation records no winner")
 app._begin_drag(p,-1); move(app,.3); app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(not app.dragging and not app.busy,"focus loss cancels gesture")
 app._begin_drag(p,-1); move(app,.3); app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 check(not app.dragging and not app.busy,"pause cancels gesture")
 app._begin_drag(point(app,PI-.05),-1)
 rotation_before=app.wheel.rotation
 move(app,-PI+.05)
 check(is_equal_approx(app.wheel.rotation-rotation_before,.1),"angle wrap crosses seam continuously")
 app._cancel_drag()
 app._begin_drag(p,-1); move(app,.3)
 app.drag_last_time-=3.0
 app._end_drag()
 check(not app.busy and app.preset.history.is_empty(),"holding still before release suppresses stale flick")
 for direction in [1.0,-1.0]:
  var prior_count: int=app.preset.history.size()
  app._begin_drag(point(app,0),-1)
  move(app,direction*.4)
  var release_rotation: float=app.wheel.rotation
  app._end_drag()
  check(app.busy and not app.dragging,"qualified flick starts coast")
  check(is_equal_approx(app.spin_start,release_rotation),"release position continuous")
  print("FLICK intended=",direction," velocity=",app.spin_initial_velocity," distance=",app.spin_distance)
  check(signf(app.spin_distance)==direction,"coast follows flick direction")
  check(app.spin_seconds==1.0,"coast uses configured duration")
  var previous: float=app.spin_start
  var monotonic:=true
  for step in range(101):
   app._animate_spin(float(step)/100)
   if (app.wheel.rotation-previous)*direction < -.0001: monotonic=false
   previous=app.wheel.rotation
  check(monotonic,"coast never reverses direction")
  app._animate_spin(0)
  mouse(app,true,p); mouse(app,false,p)
  check(app.preset.history.size()==prior_count,"extra input does not prematurely commit")
  await create_timer(1.2).timeout
  check(app.preset.history.size()==prior_count+1 and not app.busy,"flick records exactly one result")
  check(winner_at_pointer(app)==app.preset.history.back().name,"flick pointer matches recorded winner")
 app._begin_drag(point(app,0),-1)
 move(app,.18,.2)
 var slow_velocity: float=app.drag_velocity
 app._end_drag()
 check(app.busy and absf(app.spin_initial_velocity-slow_velocity)<.05 and absf(app.spin_initial_velocity)<1.0,"slow valid flick preserves release velocity without speed jump")
 await create_timer(1.2).timeout
 app._open_editor(); app._begin_drag(point(app,0),-1)
 check(not app.dragging,"modal blocks wheel gesture")
 app._close_editor()
 app.queue_free(); await settle()
 for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute("user://state.json"+suffix)
 print("GESTURE_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
