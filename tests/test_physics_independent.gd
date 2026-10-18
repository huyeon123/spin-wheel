extends SceneTree
## Independent scalar-motion, input, persistence, boundary, and native-pixel QA.
## Always run against fresh XDG_DATA_HOME. Does not modify application scripts.
const Model = preload("res://scripts/wheel_model.gd")
const Physics = preload("res://scripts/wheel_physics.gd")
const Duration = preload("res://scripts/duration_input.gd")
var checks := 0
var failures := 0
var app

func _init() -> void:
 load("res://scripts/wheel_layer.gd").reduced_motion = true
 if FileAccess.file_exists("user://state.json") or FileAccess.file_exists("user://state.json.bak"):
  push_error("Independent physics QA needs fresh isolated state."); quit(2); return
 call_deferred("run")

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures += 1; push_error("INDEPENDENT: " + label)

func settle() -> void:
 for i in range(5): await process_frame

func near_angle(a: float, b: float, tolerance: float = 0.00006) -> bool:
 return absf(wrapf(a - b, -PI, PI)) < tolerance

func float32(value: float) -> float:
 var buffer := PackedFloat32Array([value])
 return buffer[0]

func reference_winner(slices: Array, angle: float) -> int:
 var total := 0.0
 for s in slices: total += float(s.weight)
 var turn := fposmod(-angle / TAU, 1.0)
 var covered := 0.0
 for i in range(slices.size()):
  covered += float(slices[i].weight) / total
  if turn < covered or i == slices.size()-1: return i
 return -1

func make_slices(weights: Array) -> Array:
 var result: Array = []
 for i in range(weights.size()):
  result.append({"id":"ind_"+str(i), "name":"Item "+str(i), "color":["#e22c35", "#29b863", "#255ade", "#eac828"][i%4], "weight": weights[i]})
 return result

func reset_preset(weights: Array = [1.0, 2.0, 3.0, 4.0]) -> void:
 var p: Dictionary = Model.default_data().presets[0]
 p.physics_enabled = true
 p.slices = make_slices(weights)
 p.remaining_ids = p.slices.map(func(s): return s.id)
 app.data.presets = [p]
 app.preset = p
 app.data.settings.sound = false
 app._definition_changed()
 app._refresh_result()
 app.application_focused = true
 app.application_paused = false
 app.skip_coast_frame = false

func manual_spin(direction: float, speed: float) -> void:
 app._spin(direction, speed)
 app.set_process(false)

func find_named(node: Node, name_value: String) -> Array:
 var found: Array = []
 for child in node.get_children():
  if child.name == name_value: found.append(child)
  found.append_array(find_named(child, name_value))
 return found

func find_duration(node: Node) -> Node:
 for child in node.get_children():
  if child.get_script() == Duration: return child
  var found := find_duration(child)
  if found != null: return found
 return null

func point(angle: float) -> Vector2:
 var holder = app.wheel.get_parent()
 return holder.get_global_transform_with_canvas() * (holder.size/2 + Vector2.from_angle(angle) * minf(holder.size.x, holder.size.y) * 0.3)

func close_history() -> void:
 for view in get_nodes_in_group("history_views"): view.queue_free()
 await settle()

func run() -> void:
 # An independently computed constant-friction energy equation and derivative.
 for speed in [-40.0, -17.3, -0.6, 0.0, 0.6, 17.3, 40.0, 999.0]:
  var bounded := minf(absf(speed), 40.0)
  var stop := bounded/2.4
  var distance := signf(speed)*bounded*bounded/4.8
  for t in [0.0, stop*0.25, stop*0.5, stop, stop+10000.0]:
   var sample: Dictionary = Physics.sample(-0.731, speed, t)
   var elapsed := minf(stop,t)
   check(absf(sample.angle-(-0.731+signf(speed)*(bounded*elapsed-1.2*elapsed*elapsed))) < 1e-10, "analytic angle")
   check(absf(sample.velocity-signf(speed)*maxf(0,bounded-2.4*elapsed))<1e-10, "linear friction velocity")
  check(absf(Physics.sample(-0.731,speed,stop+10).angle+0.731-distance)<1e-10,"energy stopping distance")
 for bad in [NAN, INF, -INF]:
  for sample in [Physics.sample(bad,1,1), Physics.sample(1,bad,1), Physics.sample(1,1,bad)]:
   check(sample.finished and is_finite(sample.angle) and sample.velocity==0,"nonfinite motion safe")
 check(Physics.sample(1,10,-1).angle==1,"negative elapsed never extrapolates")
 # The geometry used to paint and choose must reject invalid data consistently.
 for weights in [[], [0.0,1.0], [-1.0,1.0], [NAN,1.0], [INF,1.0], ["1",1.0], [null,1.0], [1e308,1e308]]:
  var slices := make_slices(weights)
  check(Model.slice_geometry(slices).is_empty(),"invalid geometry rejected")
  check(Model.index_at_rotation(slices,0.3)==-1,"invalid geometry yields no winner")
 for weights in [[1.0,1.0],[1.0,1000000.0],[1000000.0,1.0],[1e-10,1.0,1e-10],[1.0,1e-10,1.0],[1e-300,1e-300]]:
  var slices := make_slices(weights)
  var geometry: Array = Model.slice_geometry(slices)
  check(geometry.size()==weights.size(),"valid max or tiny weights retained")
  check(geometry[0].start_angle==0 and geometry.back().end_angle==TAU,"geometry closes seam exactly")
  for wedge in geometry:
   check(wedge.sweep>=0 and is_finite(wedge.center_angle),"finite nonnegative tiny geometry")
   if wedge.sweep>1e-12: check(Model.index_at_rotation(slices,-wedge.center_angle)==wedge.index,"tiny/max center maps")
  for angle in [0.0, TAU, -TAU, 0.001, -0.001, 1000.123,-1000.123]:
   check(Model.index_at_rotation(slices,angle)==reference_winner(slices,angle),"independent angular membership")
 var max_weights: Array = []
 for i in range(200): max_weights.append(1000000.0 if i%2 else 1.0)
 check(Model.slice_geometry(make_slices(max_weights)).size()==200,"maximum number of slices")
 var equal := make_slices([1.0,1.0,1.0,1.0])
 for i in range(4):
  var edge := TAU*float(i)/4.0
  check(Model.index_at_rotation(equal,-edge)==i,"exact half-open edge")
  check(Model.index_at_rotation(equal,-edge-1e-8)==i,"just after edge")
  check(Model.index_at_rotation(equal,-edge+1e-8)==posmod(i-1,4),"just before edge")
 for value in ["true", 1, null, [], {}]:
  var raw: Dictionary = Model.default_data(); raw.presets[0].physics_enabled=value
  check(not Model._sanitize(raw).presets[0].physics_enabled,"malformed migration defaults OFF")
 var old: Dictionary = Model.default_data(); old.presets[0].erase("physics_enabled")
 old.presets[0].history=[{"name":"Old","at":"2020"}]
 var clean: Dictionary = Model._sanitize(old)
 check(not clean.presets[0].physics_enabled and not clean.presets[0].history[0].has("spin_mode"),"legacy migration preserves unmarked history")

 root.size = Vector2i(960,800)
 app = load("res://main.tscn").instantiate(); root.add_child(app); current_scene=app; await settle()
 check(not app.is_processing(),"idle app has no process loop")
 # Same real input and starting orientation must give the same output across
 # frame partitions, RNG states, and irrelevant duration settings.
 var cases := [[1.0,0.6,0.0],[-1.0,0.6,0.0],[1.0,7.5,2.317],[-1.0,7.5,-2.317],[1.0,40.0,5.912],[-1.0,40.0,-15.3]]
 for c in cases:
  var endpoints: Array = []
  var winners: Array = []
  for rate in [24.0,60.0,144.0]:
   reset_preset()
   app.preset.duration_override=1.0 if rate==24 else 30.0
   app.rng.seed=int(rate*73)
   app.wheel.rotation=c[2]
   var release: float=app.wheel.rotation
   var rng_before: int=app.rng.state
   manual_spin(c[0],c[1])
   check(app.rng.state==rng_before,"physical flick consumes no selection randomness")
   check(app.preset.history.is_empty() and app.busy,"no winner committed at start")
   check(near_angle(release,app.spin_start),"release orientation continuous")
   var expected: float=fposmod(app.spin_start+c[0]*c[1]*c[1]/4.8,TAU)
   var before: float=app.wheel.rotation
   var frame_count:=0
   var monotonic:=true
   while app.busy and frame_count<3000:
    app._process(1.0/rate)
    var traveled:=wrapf(app.wheel.rotation-before,-PI,PI)
    if traveled*c[0]<-0.00006: monotonic=false
    before=app.wheel.rotation; frame_count+=1
   check(monotonic,"CW/CCW coast never reverses")
   check(not app.busy and frame_count<3000,"coast terminates")
   check(near_angle(app.wheel.rotation,expected,0.000001),"actual final transform equals energy endpoint")
   check(app.preset.history.size()==1,"one winner per completed flick")
   var idx:=reference_winner(app.wheel.slices,app.wheel.rotation)
   check(app.preset.history[0].slice_id==app.wheel.slices[idx].id,"independent actual pointer matches result")
   check(app.result.text==app.preset.history[0].name,"result label matches committed winner")
   check(not app.is_processing(),"completed coast stops processing")
   endpoints.append(app.wheel.rotation); winners.append(app.preset.history[0].slice_id)
  check(endpoints[0]==endpoints[1] and endpoints[1]==endpoints[2],"different frame rates have identical final real_t angle")
  check(winners[0]==winners[1] and winners[1]==winners[2],"duration/RNG do not affect deterministic physics winner")

 # Button spin randomness is exactly the two impulse draws, not a selection.
 reset_preset()
 var oracle:=RandomNumberGenerator.new(); oracle.seed=48291; app.rng.seed=48291
 var expected_velocity:=oracle.randf_range(12.0,24.0)*(-1.0 if oracle.randf()<0.5 else 1.0)
 app.spin_button.pressed.emit(); await process_frame; app.set_process(false)
 check(app.physics_coasting and app.spin_initial_velocity==expected_velocity,"button uses bounded signed impulse")
 check(app.rng.state==oracle.state,"button consumes only impulse randomness")
 var last_time: float=absf(expected_velocity)/2.4-0.0001
 app._process(last_time-app.coast_elapsed)
 var pre_final: float=app.wheel.rotation
 check(app.preset.history.is_empty(),"no early commit just before rest")
 app._process(0.0002)
 check(near_angle(app.wheel.rotation,pre_final),"last frame has no snapping correction")
 check(app.preset.history.size()==1,"button completion commits once")

 # Actual mouse/touch gesture entry paths and interruptions.
 for direction in [-1.0,1.0]:
  reset_preset(); app.wheel.rotation=-7.0; app.current_rotation=-7.0
  var down:=InputEventScreenTouch.new(); down.index=0; down.pressed=true; down.position=point(0); app._input(down)
  app.drag_last_time-=0.1
  var move:=InputEventScreenDrag.new(); move.index=0; move.position=point(direction*0.4); app._input(move)
  var release: float=app.wheel.rotation
  var up:=InputEventScreenTouch.new(); up.index=0; up.position=point(direction*0.4); app._input(up); app.set_process(false)
  check(app.physics_coasting and signf(app.spin_initial_velocity)==direction,"touch flick respects signed velocity")
  check(near_angle(app.spin_start,release),"touch release has no angular jump")
  var token: int=app.spin_token
  app._spin(); app._reset_round(); app._new_preset(); app._history(); app._begin_drag(point(0),-1)
  check(app.spin_token==token and app.data.presets.size()==1 and not app.dragging,"coasting blocks duplicate spin/edit/history/drag")
  app._process(100)
  check(app.preset.history.size()==1,"touch flick finishes once")
 reset_preset()
 app._begin_drag(point(0),-1); app.drag_last_time-=0.1; app._move_drag(point(0.4))
 app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(not app.dragging and not app.busy and app.preset.history.is_empty(),"background during drag abandons without history")
 app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
 reset_preset(); app.preset.remove_override=true
 manual_spin(1,12)
 app._process(0.5)
 var paused_angle: float=app.wheel.rotation
 var paused_time: float=app.coast_elapsed
 app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 app._process(10000)
 check(app.wheel.rotation==paused_angle and app.coast_elapsed==paused_time,"background holds time and angle")
 check(not app.is_processing() and app.preset.history.is_empty(),"background disables processing and commits nothing")
 app._notification(Node.NOTIFICATION_APPLICATION_RESUMED); app.set_process(false)
 app._process(10000)
 check(app.coast_elapsed==paused_time,"resume while unfocused stays paused")
 app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN); app.set_process(false)
 app._process(10000)
 check(app.coast_elapsed==paused_time,"first foreground delta discarded")
 for bad in [NAN,INF,-1.0]: app._process(bad)
 check(app.coast_elapsed==paused_time,"bad deltas never poison state")
 app._process(100)
 var winner: Dictionary=app.preset.history[0]
 var token: int=app.spin_token
 for i in range(3): app._finish_spin(token,winner,app.wheel.rotation); app._process(100)
 check(app.preset.history.size()==1 and app.preset.remaining_ids.size()==3,"resume/duplicate finish removes and records once")
 check(app.wheel.slices.size()==4,"result retains the original landed wheel")
 var persisted: Dictionary=Model.load_data()
 check(persisted.presets[0].history.size()==1 and persisted.presets[0].remaining_ids.size()==3,"atomic result persisted once")
 check(persisted.presets[0].history[0].spin_mode=="physics","physical provenance survives disk")

 # Duration toggles preserve explicit fractional and inherited values.
 for override in [7.25,null]:
  reset_preset(); app.data.settings.duration=9.75; app.preset.duration_override=override
  app._open_editor(); await settle()
  var field:=find_duration(app.editor)
  var toggle: CheckButton=find_named(app.editor,"PhysicsRotation")[0]
  check(field!=null and not field.editable,"duration field disabled in physics")
  toggle.button_pressed=false
  check(app.preset.duration_override==override and field.value==(9.75 if override==null else override),"OFF restores exact saved duration source/value")
  check(field.editable==(override!=null),"OFF restores inherited/custom editability")
  toggle.button_pressed=true
  check(not field.editable and app.preset.duration_override==override,"ON does not rewrite duration")
  app._close_editor(); await settle()
  check(app.preset.duration_override==override,"closing editor keeps duration")
 # Both summary and every pagination use metadata, regardless of current mode.
 reset_preset()
 for i in range(205):
  var record: Dictionary={"slice_id":"ind_0","name":"Record "+str(i),"color":"#e22c35","at":"2026-10-18"}
  if i%3==0: record.spin_mode="physics"
  elif i%3==1: record.spin_mode="weighted"
  app.preset.history.append(record)
 app.preset.physics_enabled=false; app._save()
 app._history(); await settle()
 check(find_named(app.history_dialog,"PhysicsHistoryBadge").size()==1,"recent summary badges only physical records")
 await close_history()
 for page in [0,1,2]:
  app._history_details(page); await settle()
  var views:=get_nodes_in_group("history_views")
  var expected_count:=0
  var start: int=204-page*100
  for i in range(start,maxi(-1,start-100),-1):
   if i%3==0: expected_count+=1
  check(views.size()==1 and find_named(views[0],"PhysicsHistoryBadge").size()==expected_count,"full-history page badges from recorded mode")
  await close_history()
 # Incomplete coast shutdown: save old history/round only; reload idle.
 reset_preset(); app.preset.remove_override=true; manual_spin(-1,40); app._process(0.25)
 app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 var on_close: Dictionary=Model.load_data()
 check(on_close.presets[0].history.is_empty() and on_close.presets[0].remaining_ids.size()==4,"close during coast saves no phantom result/removal")
 app.queue_free(); await settle()
 app=load("res://main.tscn").instantiate(); root.add_child(app); current_scene=app; await settle()
 check(not app.busy and not app.physics_coasting and not app.is_processing(),"relaunch starts idle without resuming an unfinished result")
 check(app.preset.history.is_empty() and app.preset.remaining_ids.size()==4,"relaunch keeps uncommitted round intact")

 # Native renderer verifies pointer-facing wedge colors at both directions.
 if DisplayServer.get_name()!="headless":
  reset_preset([1.0,2.0,3.0,4.0])
  app.wheel.show_labels=false
  for direction in [-1.0,1.0]:
   # Keep the pixel sample away from a deliberately painted white separator.
   app.wheel.rotation=0.371
   manual_spin(direction,12); app._process(100); await settle()
   var frame: Image=root.get_texture().get_image()
   var holder=app.wheel.get_parent()
   var radius: float=minf(holder.size.x,holder.size.y)/2-12
   var logical: Vector2=holder.get_global_transform_with_canvas()*(holder.size/2+Vector2(0,-radius*0.8))
   var pixel: Vector2=root.get_final_transform()*logical
   var actual:=frame.get_pixel(roundi(pixel.x),roundi(pixel.y))
   var wanted:=Color(app.preset.history.back().color)
   check(Vector3(actual.r,actual.g,actual.b).distance_to(Vector3(wanted.r,wanted.g,wanted.b))<0.06,"native pixels beneath pointer agree with actual winner")
   frame.save_png("res://build/qa-independent/physics-pointer-"+str(int(direction))+".png")
 app.queue_free(); await settle()
 for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute("user://state.json"+suffix)
 print("PHYSICS_INDEPENDENT_QA: ",checks," checks, ",failures," failures; renderer=",DisplayServer.get_name())
 quit(1 if failures else 0)
