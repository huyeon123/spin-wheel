extends SceneTree
var checks:=0
var failures:=0
func _init()->void:
 # Legacy behavior fixtures explicitly opt out; real timing is tested separately.
 load("res://scripts/wheel_layer.gd").reduced_motion = true
 if FileAccess.file_exists("user://state.json") or FileAccess.file_exists("user://state.json.bak"):
  push_error("Fixed layer tests need isolated data.");quit(2);return
 call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func settle()->void:
 for i in range(5):await process_frame
func all(node:Node,type:String)->Array:
 var found:=[]
 for child in node.get_children(true):
  if child.is_class(type):found.append(child)
  found.append_array(all(child,type))
 return found
func key(code:Key,shift:bool=false)->void:
 var event:=InputEventKey.new();event.keycode=code;event.pressed=true;event.shift_pressed=shift;root.push_input(event,true)
func click(pos:Vector2)->void:
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=pos;event.global_position=pos;root.push_input(event,true)
func drag(from:Vector2,to:Vector2)->void:
 var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=from;root.push_input(press,true)
 var motion:=InputEventMouseMotion.new();motion.position=to;motion.relative=to-from;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true)
 var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=to;root.push_input(release,true)
func tap(pos:Vector2)->void:
 for down in [true,false]:
  var event:=InputEventScreenTouch.new();event.index=0;event.pressed=down;event.position=pos;Input.parse_input_event(event)
  await process_frame
func run()->void:
 root.size=Vector2i(480,800)
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 var gear:Button
 for b in all(app,"Button"):
  if b.tooltip_text=="설정":gear=b
 await tap(gear.global_position+gear.size/2);await settle()
 check(app._has_layer(),"native touch tap opens settings gear")
 var hub=app._top_layer()
 await tap(hub._close.global_position+hub._close.size/2);await settle()
 check(not app._has_layer(),"native touch tap closes settings")
 app._open_editor();await settle()
 var layer=app.editor_dialog
 check(layer._scroll.scroll_vertical==0,"opening editor begins at top")
 check(layer.title=="룰렛 편집","editor has separate roulette editing title")
 check(layer is Control and not layer is Window,"editor is true Control overlay")
 check(all(app,"Window").is_empty(),"no Window or Popup descendants in editor")
 var rect:Rect2=layer.card.get_global_rect()
 drag(rect.position+Vector2(60,20),rect.position+Vector2(140,80));await settle()
 check(layer.card.get_global_rect()==rect,"dragging header cannot move modal")
 drag(rect.end-Vector2(2,2),rect.end+Vector2(60,60));await settle()
 check(layer.card.get_global_rect()==rect,"dragging corner cannot resize modal")
 var focus_stayed:=true
 for i in range(60):
  key(KEY_TAB,i%3==0)
  var focused=root.gui_get_focus_owner()
  if focused==null or not layer.is_ancestor_of(focused):focus_stayed=false
 check(focus_stayed,"Tab and ShiftTab focus trapped in overlay")
 key(KEY_SPACE);await settle()
 check(not app.busy,"Space does not spin behind modal")
 click(Vector2(4,4));await settle()
 check(not layer.visible and not app.busy,"backdrop tap closes overlay without background action")
 app._close_editor();await settle()
 app._new_preset();await settle()
 app._preset_manager();await settle()
 var choices=app.manager_dialog
 check(choices is Control and not choices is Window,"preset manager uses Control overlay")
 var button:Button
 for candidate in all(choices.content,"Button"):
  if candidate.text=="선택":button=candidate;break
 check(button!=null,"preset selection button found for real input dispatch")
 await tap(button.global_position+button.size/2);await settle()
 check(app.preset.id==app.data.presets[0].id,"native touch selects preset without detaching viewport")
 app._manager_edit(app.preset.id);await settle()
 check(app.editor_dialog.visible and app._top_layer()==app.editor_dialog,"manager edit opens only editor")
 app._pick_color(app.preset.slices[0]);await settle()
 var color_layer=app._top_layer()
 check(color_layer is Control and not color_layer is Window,"color picker contained in fixed overlay")
 check(all(app,"ColorPickerButton").is_empty(),"no native ColorPickerButton popup remains")
 var visible_windows:=false
 for window in all(app,"Window"):
  if window.visible:visible_windows=true
 check(not visible_windows,"color editor opens no visible native Window")
 var picker:ColorPicker=all(color_layer,"ColorPicker")[0]
 check(not picker.presets_visible and not picker.sampler_visible and not picker.color_modes_visible,"color popup-producing extras disabled")
 var color_field_reached:=false
 var native_text_menu:=false
 for field in all(color_layer,"LineEdit"):
  if field.is_visible_in_tree() and field.context_menu_enabled:native_text_menu=true
 for i in range(60):
  key(KEY_TAB)
  if root.gui_get_focus_owner() is LineEdit and color_layer.is_ancestor_of(root.gui_get_focus_owner()):color_field_reached=true
 check(color_field_reached,"Tab can reach internal color numeric and hex inputs")
 check(not native_text_menu,"color text fields cannot open native context popup")
 picker.color_changed.emit(Color("#123456"));app._close_top_layer();await settle()
 check(app.preset.slices[0].color=="#123456" and app.editor_dialog.visible,"closing color layer retains chosen color and returns editor")
 for i in range(12):app._add_slice()
 await settle()
 app.editor_dialog._scroll.scroll_vertical=10000
 await settle()
 check(app.editor_dialog._scroll.scroll_vertical>0,"overflow editor content scrolls")
 root.size=Vector2i(360,640);await settle()
 rect=app.editor_dialog.card.get_global_rect()
 check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=app.size.x+1 and rect.end.y<=app.size.y+1,"modal responsive at small viewport")
 key(KEY_ESCAPE);await settle()
 check(not app._has_layer(),"Escape closes final overlay")
 app.queue_free();await settle()
 for suffix in ["", ".bak", ".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("FIXED_LAYER_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
