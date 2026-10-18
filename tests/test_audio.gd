extends SceneTree
const Audio=preload("res://scripts/wheel_audio.gd")
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
 for i in range(4):await process_frame
func run()->void:
 var audio=Audio.new();root.add_child(audio);await settle()
 check(audio.tick.stream.loop_mode==AudioStreamWAV.LOOP_DISABLED and audio.victory.stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"both WAVs disable free-running loops")
 check(audio.tick.max_polyphony==1 and audio.victory.max_polyphony==1,"single voice prevents overlapping repeated ticks or fanfares")
 check(audio.tick.stream.get_length()<=Audio.MIN_INTERVAL,"tick is shorter than minimum spacing")
 check(audio.victory.stream.get_length()>0 and audio.victory.stream.get_length()<2,"fanfare is short")
 for direction in [-1.0,1.0]:
  for seconds in [1.0,30.0]:
   audio.begin(0,true);var start=audio.tick_count;var previous=-1;var last_time=-1.0
   var first=0;var last=0
   for step in range(int(seconds*120)+1):
    var t=float(step)/(seconds*120);var now=t*seconds
    var angle=direction*TAU*8*(1-pow(1-t,3))
    audio.advance(angle,now,true)
    if audio.tick_count!=previous and previous>=0:
     check(last_time<0 or now-last_time>=Audio.MIN_INTERVAL-.000001,"ticks capped at25Hz")
     if t<.25:first+=1
     if t>.75:last+=1
     last_time=now
    previous=audio.tick_count
   check(audio.tick_count>start,"angular travel produces ticks in both directions/durations")
   check(first>last,"deceleration reduces late tick density")
   var wins=audio.victory_count;audio.finish(true);audio.finish(true)
   check(audio.victory_count==wins+1,"completion fanfare exactly once")
 audio.begin(0,true);var before=audio.tick_count
 audio.advance(TAU*100,10,true);audio.advance(TAU*100,11,true)
 check(audio.tick_count==before+1,"dropped frame emits one tick and no stationary backlog")
 audio.begin(0,false);before=audio.tick_count;var wins=audio.victory_count;audio.advance(TAU,20,false);audio.finish(false)
 check(audio.tick_count==before and audio.victory_count==wins,"mute suppresses all sounds")
 audio.begin(0,true);audio.set_foreground(false);audio.set_foreground(true);before=audio.tick_count;wins=audio.victory_count
 audio.advance(TAU,30,true);audio.finish(true)
 check(audio.tick_count==before and audio.victory_count==wins,"background session stays silent after resume")
 audio.begin(0,true);audio.advance(TAU,40,true);audio.finish(true)
 check(audio.tick_count==before+1 and audio.victory_count==wins+1,"new spin resets foreground silence latch")
 audio.begin(0,true);audio.stop();before=audio.tick_count;wins=audio.victory_count;audio.advance(TAU,50,true);audio.finish(true)
 check(audio.tick_count==before and audio.victory_count==wins,"canceled spin cannot emit late sound")
 audio.stop();await create_timer(.1).timeout;audio.queue_free();await settle()
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 for seconds in [1.0,30.0]:
  app.data.settings.duration=seconds;app.data.settings.sound=true
  wins=app.wheel_audio.victory_count;var history=app.preset.history.size();app._spin(-1);app.tween.pause();app.tween.custom_step(seconds+.1);await settle()
  check(not app.busy and app.preset.history.size()==history+1 and app.wheel_audio.victory_count==wins+1,"app completion records one winner/fanfare at duration "+str(seconds))
 for notification in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT,Node.NOTIFICATION_APPLICATION_PAUSED]:
  app._spin();app.tween.pause();wins=app.wheel_audio.victory_count;app._notification(notification);app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);app.tween.custom_step(app.spin_seconds+.1);await settle()
  check(app.wheel_audio.victory_count==wins,"app background/focus suppresses late completion fanfare")
 app.data.settings.duration=1.0;app.wheel_audio.set_foreground(true)
 for direction in [-1.0,1.0]:
  var center=app.wheel.get_parent().get_global_rect().get_center();var radius=app.wheel.size.x*.3
  before=app.wheel_audio.tick_count;wins=app.wheel_audio.victory_count
  app._begin_drag(center+Vector2(radius,0),-1);app.drag_last_time-=.1
  app._move_drag(center+Vector2.from_angle(direction*.7)*radius)
  check(app.wheel_audio.tick_count>before,"swipe angular travel triggers ratchet in both directions")
  app._end_drag();app.tween.pause();app.tween.custom_step(1.1);await settle()
  check(app.wheel_audio.victory_count==wins+1,"swipe release completes with exactly one fanfare")
 app.wheel_audio.stop();await create_timer(.1).timeout;app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("AUDIO_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
