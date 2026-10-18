extends SceneTree
## Independent real-input regression for preset-card selection and outside taps.
const Model=preload("res://scripts/wheel_model.gd")
const Layer=preload("res://scripts/wheel_layer.gd")
const Reorder=preload("res://scripts/reorder_handle.gd")
const Wheel=preload("res://scripts/wheel_canvas.gd")
var app
var checks:=0
var failures:=0
var sentinel_clicks:=0

func _init()->void:
 if FileAccess.file_exists("user://state.json") or FileAccess.file_exists("user://state.json.bak"):
  push_error("Card/dismiss QA requires isolated fresh XDG data.");quit(2);return
 Layer.reduced_motion=false
 call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error("CARD_DISMISS: "+label)
func settle()->void:
 await create_timer(.27).timeout
func all(node:Node,type:String)->Array:
 var found:=[]
 for child in node.get_children():
  if child.is_class(type):found.append(child)
  found.append_array(all(child,type))
 return found
func center(node:Control)->Vector2:
 return node.get_global_transform_with_canvas()*(node.size/2)
func mouse(pos:Vector2,down:bool)->void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=pos;e.global_position=pos;root.push_input(e,true)
func motion(pos:Vector2,delta:Vector2=Vector2.ZERO)->void:
 var e:=InputEventMouseMotion.new();e.position=pos;e.global_position=pos;e.relative=delta;e.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(e,true)
func click(pos:Vector2)->void:
 mouse(pos,true);mouse(pos,false)
func touch(pos:Vector2,down:bool,index:int=0,canceled:bool=false)->void:
 var e:=InputEventScreenTouch.new();e.position=pos;e.index=index;e.pressed=down;e.canceled=canceled;root.push_input(e,true)
func drag_touch(pos:Vector2,delta:Vector2,index:int=0)->void:
 var e:=InputEventScreenDrag.new();e.position=pos;e.relative=delta;e.index=index;root.push_input(e,true)
func tap(pos:Vector2)->void:
 touch(pos,true);touch(pos,false)
func key(code:Key)->void:
 var e:=InputEventKey.new();e.keycode=code;e.pressed=true;root.push_input(e,true)
func dim_point()->Vector2:
 return Vector2(6,6)
func card(index:int)->Control:
 for node in all(app.manager_dialog,"PanelContainer"):
  if node.get_meta("row_index",-1)==index:return node
 return null
func label_point(index:int)->Vector2:
 for label in all(card(index),"Label"):
  if label.text==app.data.presets[index].name:return center(label)
 return center(card(index))
func button(index:int,text_value:String)->Button:
 for b in all(card(index),"Button"):
  if b.text==text_value:return b
 return null
func handle(index:int)->Control:
 for node in all(card(index),"Control"):
  if node.get_script()==Reorder:return node
 return null
func preview(index:int)->Control:
 for node in all(card(index),"Control"):
  if node.get_script()==Wheel:return node
 return null
func open_manager()->void:
 app.main_selector.grab_focus();app._preset_manager();await settle()
func close_all()->void:
 for i in range(6):
  if not app._has_layer():return
  app._close_top_layer();await settle()
func preset_ids()->Array:
 return app.data.presets.map(func(p):return p.id)

func interruption_checks()->void:
 await close_all()
 for code in [KEY_ENTER,KEY_SPACE]:
  await open_manager()
  var expected:String=app.data.presets[1].id
  card(1).grab_focus();key(code);await settle()
  check(app.preset.id==expected and not app._has_layer(),"keyboard activates focused card: "+str(code))
 await open_manager()
 var selected_id:String=app.preset.id
 var pos:=label_point(0)
 touch(pos,true,0);touch(pos+Vector2(20,0),true,1);touch(pos,false,0);touch(pos+Vector2(20,0),false,1);await settle()
 check(app._has_layer() and app.preset.id==selected_id,"multiple-finger card gesture cancels original tap")
 await close_all();await open_manager();selected_id=app.preset.id;pos=label_point(1 if app.preset.id==app.data.presets[0].id else 0)
 touch(pos,true,0);touch(pos+Vector2(20,0),true,1);touch(pos+Vector2(20,0),false,1);touch(pos,false,0);await settle()
 check(app._has_layer() and app.preset.id==selected_id,"reverse multi-touch release order cannot select")
 await close_all();await open_manager();selected_id=app.preset.id;pos=label_point(1 if app.preset.id==app.data.presets[0].id else 0)
 mouse(pos,true);app._message("Interrupt card tap","Nested layer");await settle();app._close_top_layer();await settle();mouse(pos,false);await settle()
 check(app._has_layer() and app.preset.id==selected_id,"nested open/close invalidates a stale card press")
 await close_all();await open_manager();selected_id=app.preset.id;pos=label_point(1 if app.preset.id==app.data.presets[0].id else 0)
 mouse(pos,true);app.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);app.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);mouse(pos,false);await settle()
 check(app._has_layer() and app.preset.id==selected_id,"focus loss cancels pending card mouse selection")
 await close_all();await open_manager();selected_id=app.preset.id;pos=label_point(1 if app.preset.id==app.data.presets[0].id else 0)
 touch(pos,true);app.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED);app.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED);touch(pos,false);await settle()
 check(app._has_layer() and app.preset.id==selected_id,"background pause cancels pending card touch selection")
 await close_all();app._open_editor();await settle()
 var inside:Vector2=app.editor_dialog.card.get_global_rect().get_center()
 touch(dim_point(),true,0);touch(inside,true,1);touch(dim_point(),false,0);touch(inside,false,1);await settle()
 check(app.editor_dialog.visible,"multiple fingers spanning dim and card cancel dismissal")
 await close_all();app._open_editor();await settle();inside=app.editor_dialog.card.get_global_rect().get_center()
 touch(inside,true,0);touch(dim_point(),true,1);touch(dim_point(),false,1);touch(inside,false,0);await settle()
 check(app.editor_dialog.visible,"inside-first multi-touch cannot dismiss from second finger")
 await close_all();app._open_editor();await settle()
 mouse(dim_point(),true);app._message("Interrupt dim tap","Nested layer");await settle();app._close_top_layer();await settle();mouse(dim_point(),false);await settle()
 check(app.editor_dialog.visible,"nested open/close invalidates stale dim press")
 await close_all();app._open_editor();await settle()
 mouse(dim_point(),true);app.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);app.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);mouse(dim_point(),false);await settle()
 check(app.editor_dialog.visible,"focus loss cancels pending outside mouse dismissal")
 await close_all();app._open_editor();await settle()
 touch(dim_point(),true);app.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED);app.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED);touch(dim_point(),false);await settle()
 check(app.editor_dialog.visible,"background pause cancels pending outside touch dismissal")
 await close_all();await open_manager()
 var first_id:String=app.data.presets[0].id
 click(center(button(0,"선택됨" if app.preset.id==first_id else "선택")))
 click(center(button(1,"선택됨" if app.preset.id==app.data.presets[1].id else "선택")))
 await settle()
 check(not app._has_layer() and app.preset.id==first_id,"same-frame repeated explicit choices commit first selection once")
 await close_all()
 await open_manager()
 var favorite_before:bool=app.data.presets[1].favorite
 var favorite:Button
 for candidate in all(card(1),"Button"):
  if candidate.tooltip_text.begins_with("즐겨찾기"):favorite=candidate
 click(center(button(0,"선택됨" if app.preset.id==first_id else "선택")));click(center(favorite));await settle()
 check(not app._has_layer() and app.data.presets[1].favorite==favorite_before,"queued favorite cannot mutate after manager selection starts closing")
 await close_all();await open_manager()
 click(center(button(0,"선택됨" if app.preset.id==first_id else "선택")));click(center(button(1,"삭제")));await settle()
 check(not app._has_layer(),"queued delete cannot open a dialog after manager starts closing")
 await close_all();await open_manager()
 var add_button:Button
 for candidate in all(app.manager_dialog,"Button"):
  if candidate.text=="추가":add_button=candidate
 click(center(button(0,"선택됨" if app.preset.id==first_id else "선택")));click(center(add_button));await settle()
 check(not app._has_layer(),"queued add cannot open a dialog after manager starts closing")
 await close_all()
 await open_manager()
 var from:=center(handle(0));var to:=center(handle(1))+Vector2(0,10)
 touch(from,true,0);drag_touch(to,to-from,0);touch(to,false,0);await settle()
 check(app.manager_dialog.visible,"touch handle drag leaves manager open")
 touch(dim_point(),true,1);touch(dim_point(),false,1);await settle()
 check(not app._has_layer(),"fresh touch after consumed reorder release can dismiss normally")
 await close_all()

func run()->void:
 root.size=Vector2i(390,844) if "--mobile" in OS.get_cmdline_user_args() else Vector2i(960,800)
 app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 app.data.settings.sound=false
 for i in range(1,3):
  var p:Dictionary=Model.default_data().presets[0].duplicate(true)
  p.id="card_"+str(i);p.name="Independent Preset "+str(i);app.data.presets.append(p)
 app._save()
 if "--interrupt-only" in OS.get_cmdline_user_args():
  await interruption_checks()
  app.queue_free();await settle()
  for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
  print("CARD_DISMISS_INTERRUPTION_QA: ",checks," checks, ",failures," failures")
  quit(1 if failures else 0);return
 var sentinel:=Button.new();sentinel.position=Vector2.ZERO;sentinel.size=Vector2(24,24);sentinel.text="S";sentinel.pressed.connect(func():sentinel_clicks+=1);app.add_child(sentinel)
 await open_manager()
 var target_id:String=app.data.presets[1].id
 click(center(button(1,"선택")))
 await create_timer(.05).timeout
 check(app._has_layer(),"selection exit still blocks background during animation")
 await settle()
 check(app.preset.id==target_id and not app._has_layer(),"selection button chooses and auto-closes manager")
 check(app.main_selector.text==app.preset.name,"selection refreshes the main preset label")
 check(app.data.last_preset_id=="default" and Model.load_data().last_preset_id=="default","card selection preserves last-spun startup identity")
 check(root.gui_get_focus_owner()==app.main_selector,"selection restores opener focus")
 await open_manager()
 var first_id:String=app.data.presets[0].id
 click(label_point(0));await settle()
 check(app.preset.id==first_id and not app._has_layer(),"whole-card label click selects and closes")
 await open_manager();click(label_point(0));await settle()
 check(app.preset.id==first_id and not app._has_layer(),"already selected card also closes")
 await open_manager();target_id=app.data.presets[1].id
 click(card(1).get_global_rect().position+Vector2(5,5));await settle()
 check(app.preset.id==target_id and not app._has_layer(),"card padding is part of the selectable area")
 await open_manager();target_id=app.data.presets[2].id
 tap(center(preview(2)));await settle()
 check(app.preset.id==target_id and not app._has_layer(),"touch on mini-wheel selects card")
 await open_manager();click(center(button(2,"선택됨")));await settle()
 check(not app._has_layer() and app.preset.id==target_id,"selected explicit button also closes")

 # Child actions are isolated from the surrounding selectable card.
 await open_manager()
 var selected_id:String=app.preset.id
 var star:Button
 for b in all(card(0),"Button"):
  if b.tooltip_text.begins_with("즐겨찾기"):star=b
 click(center(star));await settle()
 check(app._has_layer() and app._top_layer()==app.manager_dialog,"favorite keeps manager open")
 check(app.preset.id==selected_id and app.data.presets[0].favorite,"favorite toggles without selecting card")
 click(center(button(0,"삭제")));await settle()
 check(app._top_layer()!=app.manager_dialog and app.manager_dialog.visible,"delete opens nested confirmation")
 check(app.preset.id==selected_id and app.data.presets.size()==3,"delete press neither selects nor mutates")
 click(dim_point());await settle()
 check(app._top_layer()==app.manager_dialog and app.manager_dialog.visible,"dim cancels top confirmation only")
 check(app.data.presets.size()==3 and app.preset.id==selected_id,"confirmation dim never approves deletion")
 click(center(button(0,"룰렛 편집")));await settle()
 check(app.editor_dialog.visible and app._top_layer()==app.editor_dialog,"edit button switches directly to editor")
 check(app.preset.id==first_id,"edit targets its own card without stale competing selection")
 check(app.data.last_preset_id=="default","card edit preserves last-spun startup identity")
 await close_all()

 # Tap slop, cancellation, dragging, and scroll must not be interpreted as select.
 await open_manager();selected_id=app.preset.id
 var pos:=label_point(1)
 mouse(pos,true);motion(pos+Vector2(3,0),Vector2(3,0));mouse(pos+Vector2(3,0),false);await settle()
 check(app.preset.id==app.data.presets[1].id and not app._has_layer(),"small mouse jitter remains a tap")
 await open_manager();selected_id=app.preset.id;pos=label_point(0)
 mouse(pos,true);motion(pos+Vector2(25,0),Vector2(25,0));motion(pos,Vector2(-25,0));mouse(pos,false);await settle()
 check(app.manager_dialog.visible and app.preset.id==selected_id,"out-and-back mouse drag exceeds slop permanently")
 touch(pos,true);drag_touch(pos+Vector2(20,0),Vector2(20,0));drag_touch(pos,Vector2(-20,0));touch(pos,false);await settle()
 check(app.manager_dialog.visible and app.preset.id==selected_id,"out-and-back touch drag never selects")
 touch(pos,true);touch(pos,false,0,true);await settle()
 check(app.manager_dialog.visible and app.preset.id==selected_id,"canceled touch never selects")
 touch(pos,true);touch(pos,true,1);touch(pos,false,1);await settle()
 check(app.manager_dialog.visible and app.preset.id==selected_id,"second finger release cannot activate first tap")
 touch(pos,false,0,true);await settle()
 mouse(pos,true);motion(dim_point(),dim_point()-pos);mouse(dim_point(),false);await settle()
 check(app.manager_dialog.visible and app.preset.id==selected_id,"inside press and outside release neither selects nor dismisses")
 var before:=preset_ids()
 var from:=center(handle(0));var to:=center(handle(1))+Vector2(0,10)
 mouse(from,true);motion(to,to-from);mouse(to,false);await settle()
 check(app.manager_dialog.visible and app.preset.id==selected_id,"handle reorder does not select or dismiss")
 check(app.data.presets[1].id==before[0],"handle drag reorders exactly once")
 var handle_point:=center(handle(0));click(handle_point);await settle()
 check(app.manager_dialog.visible and app.preset.id==selected_id,"handle tap does not bubble into selection")
 for i in range(3,12):
  var p:Dictionary=Model.default_data().presets[0].duplicate(true);p.id="card_"+str(i);p.name="Independent Preset "+str(i);app.data.presets.append(p)
 app._refresh_manager();await settle()
 pos=label_point(1)
 var old_scroll:int=app.manager_dialog._scroll.scroll_vertical
 touch(pos,true);drag_touch(pos-Vector2(0,80),Vector2(0,-80));touch(pos-Vector2(0,80),false);await settle()
 check(app.manager_dialog.visible and app.preset.id==selected_id,"touch scrolling list does not select or close")
 # A scroll change between down/up also invalidates a stationary candidate.
 app.manager_dialog._scroll.scroll_vertical=0;await settle();pos=label_point(0)
 mouse(pos,true);app.manager_dialog._scroll.scroll_vertical=60;await process_frame;mouse(pos,false);await settle()
 check(app.manager_dialog.visible and app.preset.id==selected_id,"scroll position change cancels pending card tap")
 app.manager_dialog._scroll.scroll_vertical=0;await settle()
 var wheel_event:=InputEventMouseButton.new();wheel_event.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel_event.pressed=true;wheel_event.position=label_point(0);root.push_input(wheel_event,true);await settle()
 check(app.manager_dialog.visible and app.preset.id==selected_id,"wheel scrolling over card never selects")
 check(app.manager_dialog._scroll.scroll_vertical>old_scroll,"manager list remains scrollable")
 await close_all()

 # All overlay types, including nested confirmation and dropdown, share dismissal.
 var openers:Array=[func():app._open_editor(),func():app._settings(),func():app._preset_manager(),func():app._history(),func():app._message("Test","Information")]
 for i in range(openers.size()):
  app.main_selector.grab_focus();openers[i].call();await settle()
  var top=app._top_layer();var inside:Vector2=top.card.get_global_rect().position+Vector2(8,8)
  click(inside);await settle();check(is_instance_valid(top) and top.visible,"inside padding click keeps overlay "+str(i))
  mouse(dim_point(),true);await create_timer(.04).timeout
  check(is_instance_valid(top) and top.visible and not top._closing,"outside press alone does not close "+str(i))
  mouse(dim_point(),false);await settle()
  check(not app._has_layer(),"outside mouse tap closes overlay "+str(i))
  check(root.gui_get_focus_owner()==app.main_selector,"outside dismissal restores opener "+str(i))
 app._open_editor();await settle();app._pick_color(app.preset.slices[0]);await settle()
 tap(dim_point());await settle()
 check(app.editor_dialog.visible and app._top_layer()==app.editor_dialog,"touch dim closes color picker only")
 await close_all()
 var accepted:=[0]
 app._confirm("Confirm","Never accept from dim",func():accepted[0]+=1);await settle();tap(dim_point());await settle()
 check(not app._has_layer() and accepted[0]==0,"touch dim cancels confirmation")
 var dropdown=Layer.new();dropdown.is_dropdown=true;dropdown.dropdown_anchor=Rect2(200,100,180,40);app.add_child(dropdown);dropdown.add_content(Label.new());dropdown.popup_centered();await settle()
 tap(dim_point());await settle();check(not dropdown.visible,"touch dim closes dropdown on release");dropdown.queue_free();await settle()

 # Dim gestures must remain top-specific and inert through entry/exit animations.
 app.main_selector.grab_focus();app._open_editor();await settle()
 var editor=app.editor_dialog
 app._confirm("Nested","Cancel only",func():accepted[0]+=1);await settle()
 var nested=app._top_layer();var canceled:=[0];nested.canceled.connect(func():canceled[0]+=1)
 click(dim_point());click(dim_point());tap(dim_point())
 await create_timer(.05).timeout
 check(nested.visible and nested._closing and editor.visible,"repeated dim gestures remain blocked during exit")
 await settle()
 check(canceled[0]==1 and accepted[0]==0 and app._top_layer()==editor,"repeated dim gestures cancel top exactly once")
 check(editor.is_ancestor_of(root.gui_get_focus_owner()) or root.gui_get_focus_owner()==editor.card,"nested close restores parent focus")
 var outside:=dim_point();var inside:Vector2=editor.card.get_global_rect().get_center()
 mouse(outside,true);motion(inside,inside-outside);mouse(inside,false);await settle()
 check(editor.visible,"outside-to-inside drag does not dismiss")
 mouse(outside,true);motion(outside+Vector2(20,0),Vector2(20,0));motion(outside,Vector2(-20,0));mouse(outside,false);await settle()
 check(editor.visible,"outside out-and-back drag does not dismiss")
 touch(outside,true);touch(outside,false,0,true);await settle();check(editor.visible,"canceled outside touch leaves layer open")
 touch(outside,true);touch(outside,true,1);touch(outside,false,1);await settle();check(editor.visible,"secondary outside finger cannot dismiss");touch(outside,false,0,true)
 await close_all()
 app._open_editor();await create_timer(.025).timeout;click(outside);await settle()
 check(not app._has_layer(),"outside tap during entrance safely completes dismissal")
 app._open_editor();await settle();mouse(outside,true);app._message("New top","Owns the release");await settle();mouse(outside,false);await settle()
 check(app._top_layer()!=editor and editor.visible,"release from prior layer cannot dismiss newer top")
 await close_all()

 # Dismissal must apply pending editor/settings inputs before persisting.
 app.preset.physics_enabled=false;app.preset.duration_override=6.0
 app.main_selector.grab_focus();app._open_editor();await settle()
 var duration:LineEdit
 for field in all(app.editor,"LineEdit"):
  if field.get_meta("duration_input",false):duration=field
 duration.grab_focus();duration.text="8.25"
 click(outside);await settle()
 check(app.preset.duration_override==8.25,"dim close applies pending editor numeric draft")
 var saved:Dictionary=Model.load_data();var persisted:=false
 for p in saved.presets:
  if p.id==app.preset.id:persisted=p.duration_override==8.25
 check(persisted,"dim close persists editor value")
 app._settings();await settle()
 for field in all(app._top_layer(),"LineEdit"):
  if field.get_meta("duration_input",false):duration=field
 duration.grab_focus();duration.text="10.75";tap(outside);await settle()
 check(app.data.settings.duration==10.75 and Model.load_data().settings.duration==10.75,"touch dim applies and saves global duration")
 check(sentinel_clicks==0,"no dim event clicks through to underlying control")
 check(not app.busy and app.preset.history.is_empty(),"dismissal/card gestures never spin or add history")
 await interruption_checks()
 if DisplayServer.get_name()!="headless":
  app._preset_manager();await settle();root.get_texture().get_image().save_png("res://build/qa-card-dismiss.png");await close_all()
 app.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("CARD_DISMISS_QA: ",checks," checks, ",failures," failures; renderer=",DisplayServer.get_name())
 quit(1 if failures else 0)
