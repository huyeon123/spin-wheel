extends SceneTree
const Stats=preload("res://scripts/history_stats.gd")
const Model=preload("res://scripts/wheel_model.gd")
var checks:=0
var failures:=0
func _init()->void:
 load("res://scripts/wheel_layer.gd").reduced_motion=true
 if FileAccess.file_exists("user://state.json"):quit(2);return
 call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func settle()->void:
 for i in range(6):await process_frame
func named(n:Node,name:String)->Node:return n.find_child(name,true,false)
func all(n:Node,type:String)->Array:
 var found=[]
 for c in n.get_children(true):
  if c.is_class(type):found.append(c)
  found.append_array(all(c,type))
 return found
func group_for(groups:Array,id:String)->Dictionary:
 for g in groups:
  if g.slice_id==id and not g.legacy:return g
 return {}
func run()->void:
 var records=[{"slice_id":"a","name":"same","color":"#ff0000"},{"slice_id":"b","name":"same","color":"#0000ff"},{"name":"same","color":"#ffff00"},{"name":"same"},{"slice_id":"a","name":"renamed","color":"#00ff00"},{"slice_id":"a","name":"renamed","color":"invalid"}]
 var snapshot=records.duplicate(true);var summary=Stats.summarize(records)
 check(summary.total==6 and summary.groups.size()==3 and summary.legacy_count==2,"ID groups stay separate from exact-name legacy group")
 var a=group_for(summary.groups,"a");var b=group_for(summary.groups,"b")
 check(a.count==3 and a.percentage==50.0 and a.name=="renamed","renamed same ID remains one group with latest saved name")
 check(a.color==Color("#00ff00"),"latest valid stored ID color survives invalid later record without live inference")
 check(b.count==1 and b.color==Color("#0000ff"),"different ID same name is never merged")
 var legacy=summary.groups.filter(func(g):return g.legacy)[0]
 check(legacy.count==2 and legacy.color==Color("#ffff00"),"legacy exact name uses latest valid stored color")
 check(legacy.display_name!=b.display_name,"duplicate visible names have a discriminator")
 check(records==snapshot,"aggregation never rewrites legacy or new records")
 check(Stats.summarize([]).total==0 and Stats.summarize([]).groups.is_empty(),"empty history produces no invented items")
 var duplicates=[{"slice_id":"x","name":"duplicate"},{"slice_id":"y","name":"duplicate"},{"slice_id":"y","name":"duplicate"}]
 var old_groups=Stats.summarize(duplicates).groups
 duplicates.append({"slice_id":"x","name":"duplicate"});duplicates.append({"slice_id":"x","name":"duplicate"})
 var new_groups=Stats.summarize(duplicates).groups
 check(group_for(old_groups,"x").display_name==group_for(new_groups,"x").display_name and group_for(old_groups,"y").display_name==group_for(new_groups,"y").display_name,"same-name item discriminators stay stable when ranking flips")
 check(Stats.summarize([{"name":"no color"}]).groups[0].color==Stats.NEUTRAL_COLOR,"missing all stored colors uses neutral")
 var large=[]
 for i in range(10005):large.append({"slice_id":"id"+str(i%25),"name":"n","color":"#abcdef"})
 var large_summary=Stats.summarize(large);var count_sum=0;var percent_sum=0.0
 for g in large_summary.groups:count_sum+=g.count;percent_sum+=g.percentage
 check(large_summary.total==10005 and count_sum==10005 and absf(percent_sum-100)<.000001,"large full-history totals and percentages are not capped by pages")
 var data=Model.default_data();data.presets[0].history=records
 check(Model.save_data(data)==OK and Model.load_data().presets[0].history==records,"IDs and missing/invalid color history preserved through storage")
 var app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app;await settle()
 app.data.settings.duration=1.0;app.data.settings.sound=false;app._spin();app.tween.pause();app.tween.custom_step(1.1);await settle()
 var winner=app.preset.history.back()
 check(winner.has("slice_id") and app.preset.slices.any(func(x):return x.id==winner.slice_id and x.name==winner.name),"new completed spin stores actual stable winning item ID")
 check(Model.load_data().presets[0].history.back()==winner,"new winner ID persists to disk")
 app.preset.history=[]
 for i in range(205):app.preset.history.append({"slice_id":"saved_"+str(i%7),"name":"name_"+str(i%7),"color":"#123456","at":"at_%03d"%i})
 app._save();app._history();await settle()
 var dialog=app.history_dialog;var recent=named(dialog,"HistoryRecent");var bars=named(dialog,"HistoryBars")
 check(recent!=null and bars!=null and bars.is_visible_in_tree(),"recent records and bars shown together without expand action")
 var recent_texts=all(recent,"Label").map(func(x):return x.text)
 check(recent_texts.has("at_204") and recent_texts.has("at_202") and not recent_texts.has("at_201"),"summary shows exactly latest three timestamps")
 check(recent.get_global_rect().position.y<bars.get_global_rect().position.y,"recent records above statistics")
 check(not all(dialog,"Button").any(func(x):return "그래프 펼치기" in x.text or "그래프 접기" in x.text),"no obsolete badge/graph toggles")
 var rows=all(bars,"Control").filter(func(x):return x.has_meta("history_group_key"))
 check(rows.size()==5,"large statistics initially show five groups")
 var mathematical=Stats.summarize(app.preset.history)
 for row in rows:
  var expected=mathematical.groups.filter(func(g):return g.key==row.get_meta("history_group_key"))[0]
  var bar=all(row,"ProgressBar")[0]
  check(bar.get_theme_stylebox("fill").bg_color==expected.color and is_equal_approx(bar.value,expected.percentage),"actual bar uses saved group color and percentage")
  check(row.get_meta("count")==expected.count and is_equal_approx(row.get_meta("percentage"),100.0*expected.count/205),"bar count and denominator use all205 records")
 named(dialog,"HistoryMoreGroups").pressed.emit();await settle()
 bars=named(app.history_dialog,"HistoryBars");rows=all(bars,"Control").filter(func(x):return x.has_meta("history_group_key"))
 check(rows.size()==7,"more items reveals all groups without changing total")
 named(app.history_dialog,"HistoryMoreRecords").pressed.emit();await settle()
 check(named(app._top_layer(),"HistoryDetailRecords")!=null,"more records opens paginated detail")
 check(app.preset.history.size()==205 and Stats.summarize(app.preset.history).total==205,"detail page does not change aggregate denominator")
 while app._has_layer():app._close_top_layer();await settle()
 var before=Stats.summarize(app.preset.history)
 app.preset.slices[0].name="live rename";app.preset.slices[0].color="#abcdef";app.preset.slices.remove_at(0);app._save()
 check(Stats.summarize(app.preset.history)==before,"deleting or renaming live items does not rewrite saved statistics")
 while app._has_layer():app._close_top_layer();await settle()
 app.preset.history=[]
 for i in range(46):app.preset.history.append({"slice_id":"many_"+str(i),"name":"many_"+str(i),"color":"#ffffff"})
 app._history();await settle()
 var many_dialog=app.history_dialog;var more=named(many_dialog,"HistoryMoreGroups")
 more.pressed.emit();await settle()
 check(named(many_dialog,"HistoryBars").get_child_count()==25 and more.is_visible_in_tree(),"first expansion adds only20 groups")
 more.pressed.emit();await settle()
 check(named(many_dialog,"HistoryBars").get_child_count()==45,"second expansion adds next20 without duplicates")
 for i in range(10):more.pressed.emit()
 await settle()
 check(named(many_dialog,"HistoryBars").get_child_count()==46 and named(many_dialog,"HistoryMoreGroups")==null,"last expansion includes all groups and removes exhausted action")
 for viewport in [Vector2i(390,844),Vector2i(320,480)]:
  root.size=viewport;await settle()
  var card=many_dialog.card.get_global_rect()
  check(card.position.x>=0 and card.end.x<=app.get_global_rect().end.x+.1 and many_dialog._close.get_global_rect().end.x<=card.end.x,"expanded history fits narrow viewport with close inside")
  check(named(many_dialog,"HistoryBars").get_global_rect().end.x<=card.end.x,"bar statistics remain within narrow card width")
 app.preset.history=Model.load_data().presets[0].history
 app.queue_free();await settle()
 check(Stats.summarize(Model.load_data().presets[0].history)==before,"full statistics survive restart")
 load("res://scripts/wheel_layer.gd").reduced_motion=false
 var reopened=load("res://main.tscn").instantiate();root.add_child(reopened);current_scene=reopened;await settle()
 reopened._history();await create_timer(.24).timeout
 var summary_layer=reopened.history_dialog
 named(summary_layer,"HistoryMoreGroups").pressed.emit();await settle()
 named(summary_layer,"HistoryMoreRecords").pressed.emit();await create_timer(.24).timeout
 check(reopened._top_layer()!=summary_layer and summary_layer.visible,"animated details preserve summary underneath")
 reopened._close_top_layer();await create_timer(.22).timeout
 check(reopened._top_layer()==summary_layer,"animated detail close restores summary")
 var reset=all(summary_layer,"Button").filter(func(b):return b.text=="기록 초기화")[0]
 reset.pressed.emit();await create_timer(.24).timeout
 reopened._close_top_layer();await create_timer(.22).timeout
 check(reopened.preset.history.size()==205 and summary_layer.visible,"expanded reset cancellation preserves all history")
 reset.pressed.emit();await create_timer(.24).timeout
 reopened._top_layer().confirmed.emit();await create_timer(.4).timeout
 check(reopened.preset.history.is_empty() and not reopened._has_layer(),"expanded reset confirmation clears records and all history layers")
 reopened.queue_free();await settle()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://state.json"+suffix)
 print("HISTORY_STATISTICS_QA: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
