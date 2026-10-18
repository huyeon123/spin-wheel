extends SceneTree
var checks:=0
var failures:=0
func _init()->void:
 if FileAccess.file_exists("user://state.json"):quit(2);return
 call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func settle()->void:
 for i in range(5):await process_frame
func run()->void:
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 for viewport_size in [Vector2i(1280,960),Vector2i(1280,720),Vector2i(800,600),Vector2i(390,844),Vector2i(360,640),Vector2i(320,568)]:
  root.size=viewport_size
  for s in app.preset.slices:s.name="가".repeat(40)
  app._open_editor();await settle()
  var fits:=true;var states_fit:=true
  for b in app.editor.find_children("*","Button",true,false):
   if b.text=="×":
    fits=fits and b.size.x>=44 and app.editor_dialog._scroll.get_global_rect().end.x-b.get_global_rect().end.x>=10
    var glyph=b.get_theme_font("font").get_string_size("×",HORIZONTAL_ALIGNMENT_LEFT,-1,b.get_theme_font_size("font_size")).x
    for state in ["normal","hover","pressed","focus","disabled"]:
     states_fit=states_fit and b.size.x-b.get_theme_stylebox(state).get_minimum_size().x>=glyph
  check(fits,"delete44px plus inset at "+str(viewport_size))
  check(states_fit,"all delete states fit glyph at "+str(viewport_size))
  var rect=app.editor_dialog.card.get_global_rect()
  check(rect.position.x>=0 and rect.end.x<=app.size.x,"editor bounded at "+str(viewport_size))
  if viewport_size.x>=800:check(rect.size.x>560,"desktop editor widened")
  app._close_editor();await settle()
 app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("EDITOR_BOUNDS_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
