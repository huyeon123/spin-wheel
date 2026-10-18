extends SceneTree
const Model=preload("res://scripts/wheel_model.gd")
var checks:=0
var failures:=0
func _init()->void:
 # Legacy behavior fixtures explicitly opt out; real timing is tested separately.
 load("res://scripts/wheel_layer.gd").reduced_motion = true
 if FileAccess.file_exists("user://state.json"):quit(2);return
 call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func settle()->void:
 for i in range(3):await process_frame
func run()->void:
 var slices=[{"weight":1.0},{"weight":3.0},{"weight":6.0}]
 var counts=[0,0,0]
 for i in range(10000):
  var choice=Model.choose(slices,(i+.5)/10000.0);counts[choice.index]+=1
 check(counts==[1000,3000,6000],"weighted winner ratios remain1:3:6")
 for selected in [.05,.2,.7]:
  var choice=Model.choose(slices,selected);var sum=0.0;var bins=[0,0,0,0,0,0,0,0,0,0]
  for i in range(1000):
   var angle=Model.landing_angle(choice,(i+.5)/1000.0)
   var unit=(angle-choice.start_angle)/choice.sweep;sum+=unit;bins[mini(9,int(unit*10))]+=1
  check(bins==[100,100,100,100,100,100,100,100,100,100] and absf(sum/1000-.5)<.00001,"conditional landing uniform inside each selected slice")
  for edge in [0.0,1.0]:
   var angle=Model.landing_angle(choice,edge)
   check(angle>choice.start_angle and angle<choice.start_angle+choice.sweep,"ordinary boundary endpoints remain strictly inside slice")
 for sweep in [1e-3,1e-6,1e-9,1e-12]:
  var choice={"start_angle":6.0,"sweep":sweep}
  for edge in [0.0,1.0]:
   var angle=Model.landing_angle(choice,edge)
   check(angle>6.0 and angle<6.0+sweep,"tiny slice endpoints remain inside sweep "+str(sweep))
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 app.data.settings.duration=1.0;app.data.settings.sound=false;app.rng.seed=17814
 var seed_state=app.rng.state;var locations={}
 for i in range(40):
  app.data.settings.duration=30.0 if i%4==0 else 1.0
  app._spin(-1 if i%2 else 1,40 if i%5==0 else 12);app.tween.pause();app._animate_spin(1)
  var before=app.wheel.rotation;app.tween.custom_step(app.spin_seconds+.1);await settle()
  check(absf(wrapf(app.wheel.rotation-before,-PI,PI))*app.wheel.size.x*.5<.05,"completion does not visually resnap endpoint")
  var landed=fposmod(-app.wheel.rotation,TAU);var total=0.0
  for s in app.wheel.slices:total+=s.weight
  var start=0.0;var visible="";var unit=0.0
  for s in app.wheel.slices:
   var sweep=TAU*s.weight/total
   if landed>=start and landed<start+sweep:visible=s.name;unit=(landed-start)/sweep
   start+=sweep
  check(visible==app.preset.history.back().name,"final visible pointer agrees with recorded winner CW/CCW")
  locations[int(unit*100000)]=true
 check(locations.size()>35,"successive spins vary within-slice positions rather than fixed center")
 check(app.rng.state!=seed_state,"RNG advances across spins instead of reseeding each spin")
 app.data.settings.remove_winner=true
 for i in range(3):
  var previous=app.preset.remaining_ids.size();app._spin();app.tween.pause();app.tween.custom_step(app.spin_seconds+.1);await settle()
  check(app.preset.remaining_ids.size()==previous-1,"random landing preserves removal round")
 app._reset_round();check(app.preset.remaining_ids.size()==4,"round reset restores choices")
 app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("RANDOM_LANDING_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
