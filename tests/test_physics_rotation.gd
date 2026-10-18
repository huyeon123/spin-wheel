extends SceneTree
const Model = preload("res://scripts/wheel_model.gd")
const Physics = preload("res://scripts/wheel_physics.gd")
const Duration = preload("res://scripts/duration_input.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
 checks += 1
 if not value: failures += 1; push_error(label)
func _init() -> void:
 load("res://scripts/wheel_layer.gd").reduced_motion = true
 if FileAccess.file_exists("user://state.json"): quit(2); return
 call_deferred("run")
func settle() -> void:
 for i in range(4): await process_frame
func find_named(node: Node, target: String) -> Array:
 var found: Array = []
 for child in node.get_children():
  if child.name == target: found.append(child)
  found.append_array(find_named(child, target))
 return found
func find_duration(node: Node) -> Node:
 for child in node.get_children():
  if child.get_script() == Duration: return child
  var found := find_duration(child)
  if found != null: return found
 return null
func run() -> void:
 for speed in [-40.0,-24.0,-0.6,0.0,0.6,12.0,40.0]:
  var stop := absf(speed) / Physics.FRICTION
  var end: Dictionary = Physics.sample(1.234,speed,stop)
  check(end.finished and is_zero_approx(end.velocity), "exact analytic rest")
  check(absf(end.angle - (1.234 + signf(speed)*speed*speed/(2*Physics.FRICTION))) < 1e-10, "exact stopping distance")
  check(Physics.sample(1.234,speed,stop+1000).angle == end.angle, "overshoot never reverses")
  for rate in [30.0,60.0,120.0,240.0]:
   var elapsed := 0.0
   while elapsed < stop: elapsed += 1.0/rate
   check(absf(Physics.sample(1.234,speed,elapsed).angle-end.angle)<1e-10, "frame rate independent endpoint")
 check(Physics.sample(0,100,100).angle == Physics.sample(0,40,100).angle, "maximum speed bounded")
 var slices: Array = Model.default_data().presets[0].slices
 var geometry: Array = Model.slice_geometry(slices)
 for wedge: Dictionary in geometry:
  check(Model.index_at_rotation(slices,-wedge.center_angle)==wedge.index,"center mapping")
  check(Model.index_at_rotation(slices,-wedge.start_angle)==wedge.index,"half-open boundary mapping")
  check(Model.index_at_rotation(slices,-wedge.end_angle+1e-8)==wedge.index,"inside end mapping")
 check(Model.index_at_rotation(slices,-TAU)==0,"wrap seam maps first")
 check(Model.index_at_rotation(slices,NAN)==-1,"invalid angle rejected")
 var legacy: Dictionary = Model.default_data()
 legacy.presets[0].erase("physics_enabled")
 check(Model._sanitize(legacy).presets[0].physics_enabled == false,"legacy defaults OFF")
 legacy.presets[0].physics_enabled = "yes"
 check(Model._sanitize(legacy).presets[0].physics_enabled == false,"malformed flag defaults OFF")
 root.size=Vector2i(480,800)
 var app = load("res://main.tscn").instantiate(); root.add_child(app); current_scene=app; await settle()
 check(not app.is_processing(),"idle processing disabled")
 app.set_process(false)
 app.data.settings.sound=false
 app.preset.physics_enabled=true
 app.preset.duration_override=7.25
 app.preset.remove_override=true
 var original_ids: Array=app.preset.remaining_ids.duplicate()
 var rng_before: int=app.rng.state
 app._spin(-1.0,12.0)
 check(app.physics_coasting and app.busy,"physics starts coasting")
 check(app.rng.state==rng_before,"flick consumes no RNG or preselected winner")
 check(app.spin_mode=="physics","mode captured at start")
 var token: int=app.spin_token
 app._process(1.0)
 var paused_angle: float=app.wheel.rotation
 var paused_elapsed: float=app.coast_elapsed
 app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 app._process(1000.0)
 check(app.wheel.rotation==paused_angle and app.coast_elapsed==paused_elapsed,"background freezes visible time")
 check(app.preset.history.is_empty(),"background creates no result")
 app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
 app.application_focused=true
 app._process(1000.0)
 check(app.coast_elapsed==paused_elapsed,"resume discards suspension frame")
 app.preset.physics_enabled=false # captured metadata must not follow later setting
 app._process(100.0)
 check(not app.busy and not app.physics_coasting,"physical coast finishes")
 check(not app.is_processing(),"finished processing disabled")
 check(app.preset.history.size()==1 and app.preset.history[0].spin_mode=="physics","physical result mode persisted from spin time")
 var winner: Dictionary=app.preset.history[0]
 var expected: int=Model.index_at_rotation(app.spin_slices,app.wheel.rotation)
 check(app.spin_slices[expected].id==winner.slice_id,"actual pointer winner matches history")
 check(app.preset.remaining_ids.size()==original_ids.size()-1 and not winner.slice_id in app.preset.remaining_ids,"winner removed once")
 app._finish_spin(token,app.spin_slices[expected],app.wheel.rotation)
 check(app.preset.history.size()==1,"duplicate finish ignored")
 check(Model.load_data().presets[0].history[0].spin_mode=="physics","history metadata survives save/load")
 check(app.wheel.slices.size()==4,"landed wheel keeps original snapshot")
 app.preset.physics_enabled=true
 app._open_editor(); await settle()
 var duration = find_duration(app.editor)
 check(duration != null and not duration.editable,"physical duration input disabled")
 var toggle: CheckButton=find_named(app.editor,"PhysicsRotation")[0]
 toggle.button_pressed=false
 check(app.preset.duration_override==7.25 and duration.editable,"OFF restores saved duration unchanged")
 toggle.button_pressed=true
 check(app.preset.duration_override==7.25 and not duration.editable,"ON preserves custom duration")
 app._close_editor(); await settle()
 app.preset.history.append({"name":"Legacy","at":"old"})
 app.preset.history.append({"name":"Normal","at":"now","spin_mode":"weighted"})
 var records := VBoxContainer.new(); root.add_child(records)
 app._history_records(records,2,-1)
 check(find_named(records,"PhysicsHistoryBadge").size()==1,"only physics record receives badge")
 records.queue_free()
 app.preset.physics_enabled=false
 app.preset.duration_override=1.0
 app.preset.remove_override=false
 var count: int=app.preset.history.size()
 app._spin()
 check(not app.physics_coasting and app.spin_mode=="weighted","OFF uses legacy tween path")
 await app.tween.finished
 check(app.preset.history.size()==count+1 and app.preset.history.back().spin_mode=="weighted","weighted commit mode correct")
 check(app.preset.history[0].spin_mode=="physics" and not app.preset.history[1].has("spin_mode"),"mode toggles do not rewrite past records")
 app.preset.physics_enabled=true
 app._spin()
 check(absf(app.spin_initial_velocity)>=12 and absf(app.spin_initial_velocity)<=24,"button impulse bounded")
 var unfinished_count: int=app.preset.history.size()
 app._save()
 app.queue_free(); await settle()
 app=load("res://main.tscn").instantiate(); root.add_child(app); current_scene=app; await settle()
 check(not app.busy and not app.physics_coasting and app.preset.history.size()==unfinished_count,"process restart abandons unfinished spin without result")
 check(app.preset.physics_enabled,"per-preset physics flag survives restart")
 app.queue_free(); await settle()
 for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute("user://state.json"+suffix)
 print("PHYSICS_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
