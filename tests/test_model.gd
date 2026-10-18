extends SceneTree

const Model = preload("res://scripts/wheel_model.gd")
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)

func sample() -> Dictionary:
	return {"id": "p", "name": "Test", "mode": "ratio", "slices": [{"id": "a", "name": "A", "color": "#ff0000", "weight": 1.0}, {"id": "b", "name": "B", "color": "#00ff00", "weight": 3.0}], "duration_override": null, "remove_override": null, "history": [], "remaining_ids": ["a", "b"]}

func _init() -> void:
	var p := sample()
	check(Model.validate_preset(p) == "", "valid ratio")
	check(Model.choose(p.slices, 0).index == 0, "zero boundary")
	check(Model.choose(p.slices, 0.249999).index == 0, "before boundary")
	check(Model.choose(p.slices, 0.25).index == 1, "exact boundary is next wedge")
	check(Model.choose(p.slices, 1).index == 1, "one boundary")
	check(Model.choose(p.slices, -1).index == 0, "negative clamp")
	check(Model.choose(p.slices, 2).index == 1, "upper clamp")
	check(Model.choose([], 0).index == -1, "empty input")
	check(Model.choose(p.slices, NAN).index == -1, "invalid random")
	check(is_equal_approx(Model.choose(p.slices, 0).center_angle, PI / 4), "center geometry")
	check(is_equal_approx(Model.choose(p.slices, 0.8).sweep, PI * 1.5), "sweep geometry")
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 908172
	rng_b.seed = 908172
	for i in range(100):
		check(Model.choose(p.slices, rng_a.randf()) == Model.choose(p.slices, rng_b.randf()), "seeded deterministic selection")
	var counts := [0, 0]
	for i in range(10000):
		var u := (i + 0.5) / 10000.0
		var choice: Dictionary = Model.choose(p.slices, u)
		counts[choice.index] += 1
		check(u * TAU >= choice.start_angle and u * TAU < choice.start_angle + choice.sweep, "selection matches geometry")
	check(counts == [2500, 7500], "normalized distribution")
	p.mode = "percent"
	check(Model.validate_preset(p) != "", "percent total invalid")
	p.slices[0].weight = 25.0
	p.slices[1].weight = 75.0
	check(Model.validate_preset(p) == "", "percent valid")
	p.slices[1].weight = 75.01
	check(Model.validate_preset(p) == "", "percent tolerance inclusive")
	p.slices[1].weight = 75.011
	check(Model.validate_preset(p) != "", "percent outside tolerance")
	for invalid in [0.0, -1.0, NAN, INF, "3", null]:
		p = sample()
		p.slices[0].weight = invalid
		check(Model.validate_preset(p) != "", "invalid weight")
		check(Model.choose(p.slices, 0.2).index == -1, "invalid probability input")
	p = sample()
	p.slices.pop_back()
	check(Model.validate_preset(p) != "", "two required")
	p = sample()
	p.remaining_ids = ["b"]
	check(Model.active_slices(p).size() == 1, "round removal")
	check(p.slices.size() == 2, "definition retained")
	check(Model.choose(Model.active_slices(p), 0.5).index == 0, "single remaining supported")
	p.remaining_ids = []
	check(Model.active_slices(p).is_empty(), "exhausted round")
	p.erase("remaining_ids")
	check(Model.active_slices(p).size() == 2, "missing round defaults full")
	for invalid_preset in [{}, {"name": "X", "mode": "ratio", "slices": null}, {"name": "X", "mode": "bad", "slices": []}]:
		check(Model.validate_preset(invalid_preset) != "", "malformed preset rejected")
	for bad in [null, [], {}, {"version": 2, "presets": []}, {"version": 1, "presets": [42]}]:
		check(Model._sanitize(bad).is_empty(), "malformed file shape rejected")
	p = sample()
	p.slices[1].id = "a"
	check(Model.validate_preset(p) != "", "duplicate IDs rejected")
	p = sample()
	p.duration_override = 0
	check(Model.validate_preset(p) != "", "duration override bounded")
	p.duration_override = 30
	check(Model.validate_preset(p) == "", "duration endpoint valid")
	p.remove_override = 1
	check(Model.validate_preset(p) != "", "boolean override required")
	var data: Dictionary = Model.default_data()
	data.presets = [sample()]
	data.last_preset_id = "p"
	var path := "user://model_test_state.json"
	check(Model.save_data(data, path) == OK, "initial save")
	check(Model.load_data(path).presets.size() == 1, "load saved")
	data.settings.duration = 9.0
	check(Model.save_data(data, path) == OK, "second save")
	check(Model.load_data(path).settings.duration == 9.0, "new state")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{bad json")
	f.close()
	check(Model.load_data(path).settings.duration == 6.0, "backup recovery")
	check(Model.save_data(data, path) == OK, "replace corruption safely")
	data.settings.duration = 100.0
	check(Model.save_data(data, path) == OK, "duration sanitize")
	check(Model.load_data(path).settings.duration == 30.0, "duration bounded")
	data.presets[0].slices[0].weight = -1
	check(Model.save_data(data, path) == ERR_INVALID_DATA, "reject invalid write")
	check(Model.load_data(path).presets[0].slices[0].weight == 1.0, "invalid write does not destroy state")
	data.presets = [sample()]
	data.presets[0].name = ""
	data.presets[0].slices[0].name = ""
	data.presets[0].mode = "percent"
	check(Model.save_data(data, path) == OK, "unfinished percent and blank labels persist")
	check(Model.load_data(path).presets[0].name == "", "draft label restored")
	check(Model.load_data(path).presets[0].mode == "percent", "draft mode restored")
	check(Model.validate_preset(Model.load_data(path).presets[0]) != "", "draft cannot spin")
	for i in range(1100):
		data.presets[0].history.append({"name": "Winner " + str(i), "color": "#ffffff", "at": "2026-10-18T00:00:00"})
	check(Model.save_data(data, path) == OK, "large history saved")
	check(Model.load_data(path).presets[0].history == data.presets[0].history, "entire history preserved")
	data.presets[0].slices = []
	check(Model.save_data(data, path) == OK, "empty draft saved")
	check(Model.load_data(path).presets[0].slices.is_empty(), "empty draft restored")
	check(Model.validate_preset(Model.default_data().presets[0]) == "", "default preset ready to spin")
	check(Model.default_data().presets[0].favorite == false, "default favorite false")
	var first := sample()
	var second := sample()
	var third := sample()
	second.id = "second"
	third.id = "third"
	first.favorite = true
	second.favorite = false
	third.favorite = "invalid legacy value"
	first.history = [{"name": "A", "color": "#ff0000", "at": "2026-10-18T06:00:00"}]
	first.remaining_ids = ["b"]
	data = Model.default_data()
	data.presets = [first, second, third]
	data.last_preset_id = "p"
	data.settings = {"duration": 7.5, "remove_winner": true, "sound": false}
	check(Model.move_entry(data.presets, 0, 2), "move preset to final index")
	check(data.presets[0].id == "second" and data.presets[1].id == "third" and data.presets[2].id == "p", "forward order correct")
	check(is_same(data.presets[2], first), "move retains dictionary identity")
	check(Model.move_entry(first.slices, 0, 1), "move slice")
	check(first.slices[0].id == "b" and first.slices[1].id == "a", "slice order correct")
	check(Model.save_data(data, path) == OK, "favorite and manual order saved")
	var restored: Dictionary = Model.load_data(path)
	check(restored.presets[2].favorite == true and restored.presets[0].favorite == false, "favorite values persist")
	check(restored.presets[1].favorite == false, "invalid favorite sanitized false")
	check(restored.presets[0].id == "second" and restored.presets[1].id == "third" and restored.presets[2].id == "p", "manual preset order persists")
	check(restored.presets[2].slices[0].id == "b" and restored.presets[2].slices[1].id == "a", "manual slice order persists")
	check(restored.presets[2].history == first.history and restored.presets[2].remaining_ids == ["b"], "reorder preserves round and history")
	var migrated_settings: Dictionary = data.settings.duplicate(true)
	migrated_settings["haptics_enabled"] = true
	check(restored.settings == migrated_settings and restored.last_preset_id == "p" and restored.version == 1, "reorder preserves settings selection and version")
	check(Model.save_data(restored, path) == OK and Model.load_data(path) == restored, "favorite/order stable across second save reload")
	check(Model.move_entry(data.presets, 2, 0) and is_same(data.presets[0], first), "backward move retains identity")
	var before_move: Array = data.presets.duplicate()
	for indexes in [[-1, 0], [0, -1], [3, 0], [0, 3]]:
		check(not Model.move_entry(data.presets, indexes[0], indexes[1]), "invalid move rejected")
		check(data.presets == before_move, "invalid move leaves order intact")
	check(Model.move_entry(data.presets, 1, 1) and data.presets == before_move, "valid no-op accepted")
	check(not Model.move_entry([], 0, 0), "empty move rejected")
	var legacy := Model.default_data()
	legacy.presets = [sample()]
	legacy.last_preset_id = "p"
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy))
	f.close()
	check(Model.load_data(path).presets[0].favorite == false, "legacy file gains favorite false")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)
	print("PASS: ", checks, " model checks")
	quit(0)
