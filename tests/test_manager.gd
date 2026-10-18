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
func all(node:Node,type:String)->Array:
 var found:=[]
 for child in node.get_children(true):
  if child.is_class(type):found.append(child)
  found.append_array(all(child,type))
 return found
func ids(entries:Array)->Array:
 return entries.map(func(x):return x.id)
func run()->void:
 root.size=Vector2i(480,800)
 var legacy=Model.default_data();legacy.presets[0].erase("favorite")
 var migrated=Model._sanitize(legacy)
 check(not migrated.presets[0].favorite,"legacy missing favorite migrates false")
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 var original=app.preset
 original.history.append({"name":"historic result","color":"#123456","at":"before"})
 original.remaining_ids.remove_at(0)
 var remaining=original.remaining_ids.duplicate();var history=original.history.duplicate(true)
 var slice_ids=ids(original.slices)
 app._reorder_slices(0,3);await settle()
 check(ids(original.slices)==[slice_ids[1],slice_ids[2],slice_ids[3],slice_ids[0]],"slice reorder moves stable identity")
 check(original.remaining_ids==remaining and original.history==history,"slice reorder preserves removal round and history")
 app._new_preset();app._new_preset();await settle()
 var order=ids(app.data.presets);var current_id=app.preset.id
 app._toggle_favorite(order[1]);await settle()
 check(ids(app.data.presets)==order and app.data.presets[1].favorite,"favorite toggles without automatic sorting")
 app._reorder_presets(1,0);await settle()
 check(ids(app.data.presets)==[order[1],order[0],order[2]] and app.preset.id==current_id,"preset reorder preserves current selection identity")
 var stored=Model.load_data()
 check(ids(stored.presets)==ids(app.data.presets) and stored.presets[0].favorite,"order and favorite persist")
 app._preset_manager();await settle()
 check(app.manager_dialog is Control and app.manager_dialog.title=="프리셋 관리","top entry opens fixed preset manager")
 check(all(app.manager_dialog,"Button").any(func(b):return b.text=="추가"),"manager has exact 추가 button")
 var previews:=0
 for child in all(app.manager_dialog,"Control"):
  if child.get_script()==load("res://scripts/wheel_canvas.gd"):previews+=1
 check(previews==3,"manager renders each preset miniwheel")
 app._add_preset_dialog();await settle()
 var add=app._top_layer();var name:LineEdit=all(add,"LineEdit")[0]
 check(all(add,"LineEdit").size()==1 and add.get_ok_button().disabled,"new preset dialog has name only and rejects empty")
 check(name.get_theme_color("font_placeholder_color").get_luminance()<0.6,"new preset placeholder is visibly dark on pale field")
 name.text="  ";name.text_changed.emit(name.text)
 check(add.get_ok_button().disabled,"whitespace name rejected")
 app._close_top_layer();await settle()
 check(app.data.presets.size()==3,"cancel add creates no preset")
 app._add_preset_dialog();await settle();add=app._top_layer();name=all(add,"LineEdit")[0]
 name.text="새 룰렛";name.text_changed.emit(name.text);add.confirmed.emit();await settle()
 check(app.data.presets.size()==4 and app.preset.name=="새 룰렛","named add creates selected preset")
 var added_id=app.preset.id
 app._manager_edit(original.id);await settle()
 check(app.editor_dialog.visible and app.editor_dialog.title=="룰렛 편집" and app.preset.id==original.id,"manager edit targets correct identity")
 var editor_buttons=all(app.editor,"Button")
 check(not editor_buttons.any(func(b):return b.text=="삭제" or b.text=="복제"),"editor has no preset management actions")
 var title:LineEdit=all(app.editor,"LineEdit")[0]
 title.text="변경한 룰렛";title.text_changed.emit(title.text);app._close_editor();await settle()
 check(app.preset.id==original.id and app.preset.history==history and app.preset.remaining_ids==remaining,"name edit retains ID history and round")
 app._manager_select(added_id);await settle()
 app._save()
 check(Model.load_data().last_preset_id=="default","browsing selection does not overwrite last-spun startup")
 app._preset_manager();await settle();app._manager_delete(added_id);await settle();app._close_top_layer();await settle()
 check(app.data.presets.size()==4,"delete cancellation preserves preset")
 app._manager_delete(added_id);await settle();app._top_layer().confirmed.emit();await settle()
 check(app.data.presets.size()==3 and app.preset.id!=added_id,"confirmed selected preset deletion safely selects survivor")
 app._close_top_layer();await settle()
 app.busy=true;var before=ids(app.data.presets)
 app._toggle_favorite(original.id);app._reorder_presets(0,2);app._preset_manager();app._add_preset_dialog()
 check(ids(app.data.presets)==before and not app._has_layer(),"spin lock blocks manager mutations and dialogs")
 app.busy=false;app._save();app.queue_free();await settle()
 var reopened=load("res://main.tscn").instantiate();root.add_child(reopened);current_scene=reopened;await settle()
 check(reopened.preset.id=="default" and reopened.preset.name=="변경한 룰렛","restart restores last-spun ID despite reordered or renamed presets")
 check(reopened.preset.history==history and reopened.preset.remaining_ids==remaining,"restart retains original history and removed state")
 check(reopened.data.presets[0].favorite,"restart retains favorite in manual order")
 reopened.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("MANAGER_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
