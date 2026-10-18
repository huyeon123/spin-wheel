extends SceneTree
const Model=preload("res://scripts/wheel_model.gd")
var checks:=0
var failures:=0
func _init() -> void:
 if FileAccess.file_exists("user://state.json") or FileAccess.file_exists("user://state.json.bak"):
  push_error("Result tests require fresh isolated user data."); quit(2); return
 call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks+=1
 if not ok: failures+=1; push_error(label)
func settle() -> void:
 for i in range(5): await process_frame
func check_result(app: Control, expected: String) -> void:
 check(app.result.text==expected,"result retains winner text")
 check(app.result.is_visible_in_tree(),"nonempty result visible")
 check(app.result.size.x>=40,"nonempty result has readable width rather than blank1px pill")
 var badge: Control=app.result.get_parent().get_parent()
 check(absf(app.result.global_position.x+app.result.size.x/2-app.size.x/2)<=1.0,"winner text is centered")
 check(badge.get_theme_stylebox("panel") is StyleBoxEmpty,"winner has no surrounding card")
 check(app.result.global_position.y>app.main_selector.global_position.y and app.result.global_position.y<app.wheel.get_parent().global_position.y,"winner sits between selector and wheel")
 check(badge.global_position.x>=0 and badge.global_position.x+badge.size.x<=app.size.x+1,"result badge fits viewport")
func run() -> void:
 root.size=Vector2i(480,800)
 var app=load("res://main.tscn").instantiate(); root.add_child(app); await settle()
 check(app.result.text.is_empty(),"empty history shows no result text")
 app.data.settings.duration=1.0; app.data.settings.sound=false
 app._spin(); await create_timer(1.2).timeout; await settle()
 var winner: String=app.preset.history.back().name
 check_result(app,winner)
 check(Model.load_data().presets[0].history.back().name==winner,"winner persisted")
 app.queue_free(); await settle()
 app=load("res://main.tscn").instantiate(); root.add_child(app); await settle()
 check_result(app,winner)
 var long_name: String="긴당첨항목이름".repeat(6)
 app.preset.history.append({"name":long_name,"color":"#ffffff","at":"test"})
 app._refresh_result(); await settle()
 check_result(app,long_name)
 root.size=Vector2i(1280,820); await settle()
 check_result(app,long_name)
 app.preset.history.clear(); app._refresh_result(); await settle()
 check(app.result.text.is_empty(),"history reset clears result text")
 app.queue_free(); await settle()
 for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute("user://state.json"+suffix)
 print("RESULT_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
