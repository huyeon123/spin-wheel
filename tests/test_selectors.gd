extends SceneTree
const Model=preload("res://scripts/wheel_model.gd")
var checks:=0
var failures:=0
func _init()->void:
 # Legacy behavior fixtures explicitly opt out; real timing is tested separately.
 load("res://scripts/wheel_layer.gd").reduced_motion = true
 if FileAccess.file_exists("user://state.json"):quit(2);return
 call_deferred("run")
func settle()->void:
 for i in range(5):await process_frame
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func all(n:Node,type:String)->Array:
 var a=[]
 for c in n.get_children(true):
  if c.is_class(type):a.append(c)
  a.append_array(all(c,type))
 return a
func button(n:Node,text:String)->Button:
 for b in all(n,"Button"):
  if b.text==text:return b
 return null
func press(b:Button)->void:
 if b.toggle_mode:b.button_pressed=true
 b.pressed.emit()
func run()->void:
 root.size=Vector2i(480,800)
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 var gear:Button
 for b in all(app,"Button"):
  if b.tooltip_text=="설정":gear=b
 gear.pressed.emit();await settle()
 check(app._top_layer().title=="전체 설정","gear directly opens global settings")
 check(not app._top_layer().show_footer and not app._top_layer()._ok.is_visible_in_tree(),"global settings has top close only")
 check(button(app._top_layer(),"현재 룰렛 설정")==null,"no intermediate settings chooser")
 var global=app._top_layer();all(global,"LineEdit").filter(func(f):return f.get_meta("duration_input",false))[0].text="9.5";all(global,"LineEdit").filter(func(f):return f.get_meta("duration_input",false))[0].apply();await settle()
 app._close_top_layer();await settle()
 check(app._duration()==9.5,"default preset inherits changed global duration")
 app._preset_settings();await settle()
 check(app._top_layer()==app.editor_dialog and app.editor_dialog._scroll.scroll_vertical>0,"preset settings are editor bottom section")
 var seconds=all(app.editor,"LineEdit").filter(func(f):return f.get_meta("duration_input",false))[0]
 check(not seconds.editable,"inherited duration field disabled")
 press(button(app.editor,"직접 설정"));seconds.text="3.5";seconds.apply()
 check(app.preset.duration_override==3.5 and app._duration()==3.5,"custom duration overrides global")
 press(button(app.editor,"제외"))
 check(app._remove_winner() and app.preset.remove_override==true,"exclude override enabled")
 press(button(app.editor,"유지"))
 check(not app._remove_winner() and app.preset.remove_override==false,"retain override enabled")
 await settle();app._close_editor();app.data.settings.duration=12;app.data.settings.remove_winner=true
 check(app._duration()==3.5 and not app._remove_winner(),"global changes do not replace explicit overrides")
 app._open_editor();await settle()
 var inherit:Button
 for b in all(app.editor,"Button"):
  if b.text.begins_with("전체 설정 사용 ·"):inherit=b
 press(inherit);press(button(app.editor,"전체 설정 사용"))
 check(app.preset.duration_override==null and app._duration()==12,"inherit duration restores current global")
 check(app.preset.remove_override==null and app._remove_winner(),"inherit removal restores current global")
 app._close_editor();await settle()
 var saved=Model.load_data().presets[0]
 check(saved.duration_override==null and saved.remove_override==null,"inheritance persists as null rather than copied values")
 app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("SELECTOR_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
