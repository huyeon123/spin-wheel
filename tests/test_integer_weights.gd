extends SceneTree
var checks:=0
var failures:=0
func _init() -> void:
 if FileAccess.file_exists("user://state.json") or FileAccess.file_exists("user://state.json.bak"):
  push_error("Integer tests require isolated user data.");quit(2);return
 call_deferred("run")
func settle() -> void:
 for i in range(5): await process_frame
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures+=1;push_error(label)
func fields(node: Node) -> Array:
 var found:=[]
 for child in node.get_children():
  if child is LineEdit and child.tooltip_text.begins_with("양의 정수"): found.append(child)
  found.append_array(fields(child))
 return found
func run() -> void:
 var app=load("res://main.tscn").instantiate();root.add_child(app);await settle()
 var slice: Dictionary=app.preset.slices[0]
 for mode in ["ratio","percent"]:
  for invalid in ["1.5","0","-1","abc","","1e2","999999999999999999999999"]:
   slice.weight=7.0
   check(not app._set_integer_weight(slice,invalid,mode) and slice.weight==7.0,"invalid pasted integer rejected without mutation: "+mode+" "+invalid)
  check(app._set_integer_weight(slice,"12",mode) and slice.weight==12.0,"integer accepted in "+mode)
 check(not app._set_integer_weight(slice,"101","percent"),"percentage input bounded100")
 check(not app._set_integer_weight(slice,"1000001","ratio"),"ratio input bounded")
 slice.weight=100000.5
 app._open_editor();await settle()
 check(app._weight_text(slice.weight).to_float()==slice.weight,"large legacy fraction displayed exactly")
 check(fields(app.editor)[0].text.to_float()==slice.weight,"visible legacy field matches actual weight")
 app._close_editor();await settle()
 check(slice.weight==100000.5,"open and close preserves legacy fraction")
 app.preset.slices.resize(3)
 app.preset.mode="ratio";app._equalize()
 check(app.preset.slices.all(func(s):return s.weight==1.0),"ratio equalize assigns one each")
 app.preset.mode="percent";app._equalize()
 check(app.preset.slices.map(func(s):return s.weight)==[34.0,33.0,33.0],"three percent equalize stable34/33/33")
 check(app._integer_percent_weights(app.preset.slices)==[34,33,33],"existing integer distribution stable")
 app.preset.mode="ratio"
 for s in app.preset.slices:s.weight=1.0
 app._change_mode(1);await settle()
 check(app.preset.mode=="percent" and app.preset.slices.map(func(s):return s.weight)==[34.0,33.0,33.0],"equal ratio conversion produces integer100total")
 app._close_top_layer();await settle()
 app._add_slice()
 check(app.spin_button.disabled,"percent add with101total disables spin")
 app._equalize()
 check(app.preset.slices.map(func(s):return s.weight)==[25.0,25.0,25.0,25.0] and not app.spin_button.disabled,"equalize repairs after add")
 app.preset.slices.pop_back();app._definition_changed()
 check(app.spin_button.disabled,"percent deletion with75total disables spin")
 app._equalize()
 check(app.preset.slices.map(func(s):return s.weight)==[34.0,33.0,33.0],"equalize repairs after deletion")
 var too_many:=[]
 for i in range(101):too_many.append({"weight":1.0})
 check(app._integer_percent_weights(too_many).is_empty(),"101 positive integer percentages impossible")
 for count in range(2,101):
  var slices:=[]
  for i in range(count):slices.append({"weight":float(i+1)})
  var distribution: Array=app._integer_percent_weights(slices)
  var total:=0
  for v in distribution:total+=v
  check(total==100 and distribution.all(func(v):return v>=1),"positive integer percent sum100 at count"+str(count))
 app.queue_free();await settle()
 for suffix in ["", ".bak", ".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("INTEGER_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
