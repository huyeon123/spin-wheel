extends SceneTree
const H = preload("res://scripts/wheel_haptics.gd")
const M = preload("res://scripts/wheel_model.gd")
var checks:=0
var failures:=0
var pulses:Array=[]
var cancellations:=0
func _init():
 load("res://scripts/wheel_layer.gd").reduced_motion=true
 if FileAccess.file_exists("user://state.json"):quit(2);return
 call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func settle():
 for i in range(5):await process_frame
func sink(ms:int,amplitude:float):pulses.append([ms,amplitude])
func cancel():cancellations+=1
func controller():
 var h=H.new();h.vibration_callback=sink;h.cancel_callback=cancel;root.add_child(h);return h
func run():
 for direction in [-1.0,1.0]:
  for seconds in [1.0,30.0]:
   var h=controller();h.begin(0,true);var last=-1.0;var count=0
   for step in range(int(seconds*120)+1):
    var now=step/120.0;var t=now/seconds
    h.advance(direction*TAU*8*(1-pow(1-t,3)),now,true)
    if h.tick_count>count:
     check(last<0 or now-last>=.1-.000001,"angular pulses at most10Hz")
     last=now;count=h.tick_count
   check(count>0,"both directions and durations pulse")
   h.finish(true);h.finish(true);check(h.victory_count==1,"victory once")
   h.queue_free();await settle()
 for p in pulses:check(p==[10,.25] or p==[40,.55],"only finite specified pulses")
 var h=controller();h.begin(0,true);h.advance(TAU*100,100,true);var n=h.tick_count
 h.advance(TAU*100,101,true);check(h.tick_count==n,"no stationary backlog")
 h.begin(0,true);h.advance(TAU,100.01,true);check(h.tick_count==n,"rate limit survives new session")
 h.advance(TAU*2,102,true);var c=cancellations;h.set_enabled(false)
 check(cancellations==c+1,"toggle off cancels immediately")
 h.advance(TAU*3,103,false);h.finish(false);check(h.victory_count==0,"disabled completion silent")
 h.begin(0,true);h.advance(TAU,104,true);c=cancellations;h.set_foreground(false)
 check(cancellations==c+1,"background cancels pending pulse")
 h.set_foreground(true);n=h.tick_count;h.advance(TAU*2,105,true);h.finish(true)
 check(h.tick_count==n and h.victory_count==0,"no late resume pulses or victory")
 h.begin(0,true);h.advance(TAU,106,true);h.finish(true);check(h.victory_count==1,"next foreground session works")
 h.begin(0,true);h.advance(NAN,107,true);h.advance(TAU,NAN,true);check(is_finite(h.previous_angle),"invalid input rejected")
 h.stop();n=h.tick_count;h.advance(TAU*4,108,true);check(h.tick_count==n,"cancel abandons session")
 h.queue_free();await settle()
 var legacy=M.default_data();legacy.settings.erase("haptics_enabled")
 check(M._sanitize(legacy).settings.haptics_enabled,"legacy default ON")
 legacy.settings.haptics_enabled=false;check(not M._sanitize(legacy).settings.haptics_enabled,"false survives migration")
 var app=load("res://main.tscn").instantiate();root.add_child(app);await settle()
 app.wheel_haptics.vibration_callback=sink;app.wheel_haptics.cancel_callback=cancel
 app.data.settings.sound=false;app._set_haptics_enabled(true)
 for physics in [false,true]:
  app.preset.physics_enabled=physics;app.preset.duration_override=1.0
  n=app.wheel_haptics.victory_count;app._spin(1.0,12.0)
  if physics:app.set_process(false);app._process(10.0)
  else:app.tween.pause();app.tween.custom_step(1.1)
  await settle();check(app.wheel_haptics.victory_count==n+1,"both modes haptic victory with sound OFF")
 app._set_haptics_enabled(false);app.data.settings.sound=true;n=app.wheel_haptics.victory_count
 app._spin(-1.0,12.0);app.set_process(false);app._process(10.0);await settle()
 check(app.wheel_haptics.victory_count==n,"haptic OFF independent of sound ON")
 check(not M.load_data().settings.haptics_enabled,"toggle persists")
 app._set_haptics_enabled(true);app._settings();await settle()
 var toggle=app._top_layer().find_child("HapticsEnabled",true,false)
 check(toggle!=null and toggle.button_pressed,"settings reflects stored flag")
 app._close_top_layer();await settle()
 var center=app.wheel.get_parent().get_global_rect().get_center();var radius=minf(app.wheel.size.x,app.wheel.size.y)*.35
 app._begin_drag(center+Vector2(radius,0),-1);app.drag_last_time-=.1
 app._move_drag(center+Vector2.from_angle(.7)*radius);check(app.wheel_haptics.active,"drag begins haptic session")
 app._cancel_drag();check(not app.wheel_haptics.active,"cancel drag stops haptics")
 app.queue_free();await settle()
 var desktop=H.new();root.add_child(desktop);desktop.begin(0,true);desktop.advance(TAU,1,true);desktop.finish(true)
 check(OS.has_feature("android") or not desktop._pulse_pending,"desktop emits no native vibration")
 desktop.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("HAPTICS_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
