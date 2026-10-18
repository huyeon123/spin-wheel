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
 for i in range(5):await process_frame
func run()->void:
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 var existing=app.preset
 existing.history.append({"name":"Preserved result","at":"2026-01-01","color":"#123456"})
 var snapshot=existing.duplicate(true)
 app._new_preset();await settle()
 var added=app.preset
 check(added.id!=existing.id and added.slices.size()==2,"new preset has exactly two new slices")
 check(added.slices.all(func(s):return s.name=="" and s.weight==1.0),"new slices have genuinely empty names and 1:1 weights")
 check(added.slices[0].id!=added.slices[1].id,"new slice IDs distinct")
 check(added.mode=="ratio" and added.history.is_empty(),"new preset ratio mode and empty history")
 check(not Model.validate_preset(added).is_empty() and app.spin_button.disabled,"blank draft cannot spin")
 app._spin();check(not app.busy and added.history.is_empty(),"direct spin call rejects empty labels")
 app._save();var stored=Model.load_data()
 var saved=stored.presets.filter(func(p):return p.id==added.id)[0]
 check(saved.slices.size()==2 and saved.slices.all(func(s):return s.name==""),"save/load preserves empty draft without sample substitution")
 check(existing==snapshot,"creating blank preset preserves existing preset and history")
 added.slices[0].name="첫 항목";app._definition_changed()
 check(app.spin_button.disabled,"one named item remains invalid")
 added.slices[1].name="두 번째";app._definition_changed()
 check(Model.validate_preset(added).is_empty() and not app.spin_button.disabled,"two named items enable spin")
 app._save();app.queue_free();await settle()
 var restored=Model.load_data().presets.filter(func(p):return p.id==added.id)[0]
 check(restored.slices[0].name=="첫 항목" and restored.slices[1].name=="두 번째","explicitly entered names persist")
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("NEW_PRESET_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
