extends SceneTree
const Duration=preload("res://scripts/duration_input.gd")
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
 for i in range(5):await process_frame
func all(n:Node)->Array:
 var a=[]
 for c in n.get_children(true):
  if c.get_meta("duration_input",false):a.append(c)
  a.append_array(all(c))
 return a
func run()->void:
 var f=Duration.new();root.add_child(f);await settle()
 check(f.virtual_keyboard_type==LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL,"numeric decimal keyboard requested")
 check(f is LineEdit and not f is SpinBox,"plain numeric field without spinner arrows")
 for valid in ["1","30","6.5","1.25","29.999","06.5"]:
  f.text=valid;f.text_changed.emit(valid);f.apply()
  check(f.value==float(valid),"valid decimal "+valid)
 for invalid in ["","0","31","-3","+2","1e1","2+3","NaN","INF","1,5","６","한글","3abc","1.2.3","."," 6 "]:
  f.set_value_no_signal(6.5);f.text=invalid;f.text_changed.emit(invalid);f.apply()
  check(f.value==6.5,"invalid pasted/composed value does not change duration: "+invalid)
 f.set_value_no_signal(6.1234567890123);var exact=f.value;f.apply()
 check(f.value==exact,"long legacy fractional duration unchanged on open/close")
 for invalid in ["1e1","+2"," 6 "]:
  f.set_value_no_signal(6.5);f.text=invalid;f.text_submitted.emit(invalid)
  check(f.value==6.5,"submission parser independently rejects "+invalid)
 if DisplayServer.get_name() != "headless":
  f.size=Vector2(200,48);f.grab_focus();await settle()
  for pasted in ["12.5","1e1","한글","31"]:
   f.set_value_no_signal(6.5);f.select_all();DisplayServer.clipboard_set(pasted)
   var key=InputEventKey.new();key.keycode=KEY_V;key.ctrl_pressed=true;key.pressed=true;root.push_input(key,true)
   key=InputEventKey.new();key.keycode=KEY_V;key.ctrl_pressed=true;key.pressed=false;root.push_input(key,true)
   await settle();f.apply()
   check(f.value==(12.5 if pasted=="12.5" else 6.5),"real GUI clipboard paste "+pasted)
  f.set_value_no_signal(6.5);f.select_all()
  var composed=InputEventKey.new();composed.unicode=0xD55C;composed.pressed=true;root.push_input(composed,true);await settle();f.apply()
  check(f.value==6.5,"committed Korean character input rejected without changing duration")
 f.queue_free();await settle()
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 app._settings();await settle();f=all(app._top_layer())[0]
 f.text="8.75";f.text_changed.emit(f.text);app._close_top_layer();await settle()
 check(app.data.settings.duration==8.75 and Model.load_data().settings.duration==8.75,"global close commits and saves plain decimal")
 app.preset.duration_override=4.25;app._open_editor();await settle();f=all(app.editor)[0]
 check(f.editable and f.value==4.25,"custom duration field loads fractional override")
 f.text="7.5";f.text_changed.emit(f.text);app._close_editor();await settle()
 check(app.preset.duration_override==7.5 and app._duration()==7.5,"individual numeric duration commits")
 app._settings();await settle();f=all(app._top_layer())[0];f.text="31";f.text_changed.emit(f.text);app._close_top_layer();await settle()
 check(app.data.settings.duration==8.75,"invalid global range retains last committed value")
 app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("DURATION_INPUT_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
