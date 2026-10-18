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
func texts(n:Node)->Array:return all(n,"Label").map(func(x):return x.text)
func press(n:Node,text:String)->void:
 for b in all(n,"Button"):
  if b.text==text:b.pressed.emit();return
 push_error("missing button "+text)
func run()->void:
 root.size=Vector2i(480,800)
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 var original=app.preset
 original.history=[]
 for i in range(205):original.history.append({"name":"winner_%03d"%i,"color":"#123456","at":"saved timestamp %03d"%i})
 original.history[204].name="가".repeat(100)
 original.history[204].erase("at")
 app._save();app._history();await settle()
 check(app.history_dialog.title=="결과 기록" and original.name in texts(app.history_dialog),"history title and preset subtitle")
 check(not app.history_dialog.show_footer and not app.history_dialog._ok.is_visible_in_tree(),"history has top close only")
 press(app.history_dialog,"기록 더 보기 ›");await settle()
 var detail=app._top_layer()
 var labels=texts(detail)
 check(labels.has("가".repeat(100)) and labels.has("winner_105") and not labels.has("winner_104"),"first page contains latest100 exact saved winner names")
 check(labels.has("saved timestamp 203") and not labels.has("saved timestamp 204"),"saved timestamps displayed without fabricating missing one")
 var dot_color:Color=all(detail,"Panel")[0].get_theme_stylebox("panel").bg_color
 check(dot_color==Color("#123456"),"history uses saved color rather than current slice color")
 press(app._top_layer(),"이전 기록");await settle();labels=texts(app._top_layer())
 check(labels.has("winner_104") and labels.has("winner_005") and not labels.has("winner_004"),"second history page is correct100 records")
 press(app._top_layer(),"이전 기록");await settle();labels=texts(app._top_layer())
 check(labels.has("winner_004") and labels.has("winner_000") and not labels.has("winner_005"),"last history page contains oldest5")
 press(app._top_layer(),"최근 기록");await settle();check(texts(app._top_layer()).has("winner_104"),"recent-page navigation works")
 check(Model.load_data().presets[0].history.size()==205,"paging never truncates persistent history")
 press(app._top_layer(),"기록 초기화");await settle();app._close_top_layer();await settle()
 check(original.history.size()==205 and app.history_dialog.visible,"reset cancellation preserves full history")
 while app._has_layer():app._close_top_layer();await settle()
 app._new_preset();var other=app.preset
 other.history=[{"name":"other result","color":"#abcdef","at":"other timestamp"}]
 app._select_preset(0);app._history();await settle()
 press(app.history_dialog,"기록 초기화");await settle();app._top_layer().confirmed.emit();await settle()
 check(original.history.is_empty() and other.history.size()==1,"confirmed reset affects selected preset only")
 check(Model.load_data().presets[0].history.is_empty(),"history reset persists")
 app._history();await settle()
 check(texts(app.history_dialog).has("아직 기록이 없습니다."),"empty state shown without invented results")
 app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("HISTORY_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
