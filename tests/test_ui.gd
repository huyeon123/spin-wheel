extends SceneTree
const Model = preload("res://scripts/wheel_model.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(label)
func _init() -> void:
 if FileAccess.file_exists("user://state.json"):
  push_error("UI tests require a fresh isolated user data directory; refusing to modify existing data.")
  quit(2)
  return
 call_deferred("run")
func frame() -> void:
 await process_frame
 await process_frame
func run() -> void:
 var app = load("res://main.tscn").instantiate()
 root.add_child(app)
 current_scene=app
 await frame()
 check(app.preset.id == "default", "default loaded")
 app.data.settings.duration = 1.0
 app.data.settings.remove_winner = true
 app.data.settings.sound = false
 check(app._duration() == 1.0 and app._remove_winner(), "global settings inherited")
 app.preset.duration_override = 2.0
 app.preset.remove_override = false
 check(app._duration() == 2.0 and not app._remove_winner(), "preset settings override")
 app.preset.duration_override = null
 app.preset.remove_override = null
 var original = app.preset
 app._new_preset()
 var created = app.preset
 check(app.data.presets.size() == 2 and created.id != original.id, "new preset independent")
 # This spin/removal fixture explicitly supplies four named choices; new drafts are blank.
 created.slices = original.slices.duplicate(true)
 for i in range(created.slices.size()): created.slices[i].id = "qa_choice_" + str(i)
 app._definition_changed()
 app._spin()
 check(app.busy and app.selectors.disabled and app.spin_button.disabled, "spin locks UI")
 app._new_preset()
 check(app.data.presets.size() == 2, "new preset blocked during spin")
 var stored = Model.load_data()
 check(stored.last_preset_id == created.id, "last spun persisted at start")
 check(stored.presets[1].history.is_empty(), "pending spin not prematurely committed")
 await create_timer(1.2).timeout
 check(not app.busy and created.history.size() == 1, "spin completed and history recorded")
 check(created.remaining_ids.size() == 3 and created.slices.size() == 4, "winner removed only from round")
 # Pointer is at -PI/2, and each painted wedge starts at -PI/2 plus cumulative angle.
 var landed = fposmod(-app.wheel.rotation, TAU)
 var cumulative := 0.0
 var landed_name := ""
 var total := 0.0
 for s in app.wheel.slices: total += float(s.weight)
 for s in app.wheel.slices:
  var end = cumulative + TAU * float(s.weight) / total
  if landed >= cumulative and landed < end: landed_name = s.name
  cumulative = end
 check(landed_name == created.history.back().name, "visible pointer lands on recorded winner")
 for i in range(2):
  app._spin()
  await create_timer(1.2).timeout
 check(created.remaining_ids.size() == 1 and app.spin_button.disabled, "minimum active count stops at one")
 app._spin()
 check(not app.busy and created.history.size() == 3, "spin cannot proceed below two")
 app._reset_round()
 check(created.remaining_ids.size() == 4 and created.history.size() == 3, "round reset preserves history")
 app._change_mode(1)
 check(created.mode == "percent" and Model.validate_preset(created) == "", "ratio to percent conversion valid")
 created.slices[0].weight = 12.0
 app._definition_changed()
 app._save()
 check(app.spin_button.disabled, "invalid percent disables spin")
 app._spin()
 check(not app.busy, "invalid percent cannot spin")
 stored = Model.load_data()
 check(stored.presets[1].slices[0].weight == 12.0 and stored.presets[1].history.size() == 3, "invalid percent draft saved without history loss")
 app._select_preset(0)
 check(app.preset.id == original.id and app.preset.history.is_empty(), "switch keeps histories separate")
 app._save()
 check(Model.load_data().last_preset_id == created.id, "browsing does not alter last-spun preset")
 app.queue_free()
 await frame()
 var reopened = load("res://main.tscn").instantiate()
 root.add_child(reopened)
 current_scene=reopened
 await frame()
 check(reopened.preset.id == created.id and reopened.preset.history.size() == 3, "relaunch restores last-spun preset and full history")
 reopened._change_mode(0)
 reopened._spin()
 reopened.tween.kill()
 reopened._save()
 stored = Model.load_data()
 check(stored.presets[1].history.size() == 3 and stored.presets[1].remaining_ids.size() == 4, "interrupted spin commits neither winner nor removal")
 reopened.queue_free()
 await frame()
 for suffix in ["", ".bak", ".tmp"]:
  if FileAccess.file_exists("user://state.json" + suffix): DirAccess.remove_absolute("user://state.json" + suffix)
 print("UI_QA: ", checks, " checks, ", failures, " failures")
 quit(1 if failures else 0)
