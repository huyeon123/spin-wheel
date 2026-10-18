class_name WheelModel
extends RefCounted
## Persistence and probability math, independent of the interface.

const MAX_PRESETS := 100
const MAX_SLICES := 200
const TAU_VALUE := PI * 2.0

static func default_data() -> Dictionary:
	return {"version": 1, "settings": {"duration": 6.0, "remove_winner": false, "sound": true}, "last_preset_id": "default", "presets": [{"id": "default", "name": "오늘의 작은 즐거움", "favorite": false, "physics_enabled": false, "mode": "ratio", "slices": [{"id": "default_1", "name": "커피 한 잔", "color": "#a89bea", "weight": 1.0}, {"id": "default_2", "name": "가벼운 산책", "color": "#ffcc75", "weight": 1.0}, {"id": "default_3", "name": "좋아하는 음악", "color": "#7ad3b9", "weight": 1.0}, {"id": "default_4", "name": "달콤한 간식", "color": "#f69ca9", "weight": 1.0}], "duration_override": null, "remove_override": null, "history": [], "remaining_ids": ["default_1", "default_2", "default_3", "default_4"]}]}

static func move_entry(entries: Array, from: int, to: int) -> bool:
	# `to` is the final index; move references without cloning or sorting.
	if from < 0 or from >= entries.size() or to < 0 or to >= entries.size():
		return false
	if from == to:
		return true
	var entry: Variant = entries.pop_at(from)
	entries.insert(to, entry)
	return true

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func validate_preset(preset: Dictionary) -> String:
	if not preset.get("name", null) is String or preset.get("name", "").strip_edges().is_empty():
		return "프리셋 이름을 입력해 주세요."
	if not preset.get("mode", null) in ["ratio", "percent"]:
		return "비율 또는 퍼센트 모드를 선택해 주세요."
	var slices: Variant = preset.get("slices", null)
	if not slices is Array or slices.size() < 2:
		return "항목을 2개 이상 추가해 주세요."
	if slices.size() > MAX_SLICES:
		return "항목은 최대 200개까지 가능합니다."
	var total := 0.0
	var ids := {}
	for slice: Variant in slices:
		if not slice is Dictionary:
			return "항목 형식이 올바르지 않습니다."
		if not slice.get("id", null) is String or slice.get("id", "").is_empty() or ids.has(slice.get("id")):
			return "항목 ID는 비어 있지 않고 서로 달라야 합니다."
		ids[slice.id] = true
		if not slice.get("name", null) is String or slice.get("name", "").strip_edges().is_empty():
			return "모든 항목의 이름을 입력해 주세요."
		if not slice.get("color", null) is String or not Color.html_is_valid(slice.get("color", "")):
			return "항목 색상이 올바르지 않습니다."
		if not _number(slice.get("weight")) or float(slice.weight) <= 0.0:
			return "비율은 0보다 큰 숫자여야 합니다."
		total += float(slice.weight)
	if not is_finite(total):
		return "비율의 합이 너무 큽니다."
	if preset.mode == "percent" and absf(total - 100.0) > 0.010000001:
		return "퍼센트 합계가 100%여야 합니다."
	var duration: Variant = preset.get("duration_override", null)
	if duration != null and (not _number(duration) or float(duration) < 1.0 or float(duration) > 30.0):
		return "회전 시간은 1~30초여야 합니다."
	var removal: Variant = preset.get("remove_override", null)
	if removal != null and not removal is bool:
		return "당첨 항목 제외 설정이 올바르지 않습니다."
	return ""

static func active_slices(preset: Dictionary) -> Array:
	var slices: Variant = preset.get("slices", [])
	if not slices is Array:
		return []
	if not preset.has("remaining_ids"):
		return slices.duplicate(true)
	var remaining: Variant = preset.remaining_ids
	if not remaining is Array:
		return []
	var result: Array = []
	for slice: Variant in slices:
		if slice is Dictionary and slice.get("id") in remaining:
			result.append(slice.duplicate(true))
	return result

static func choose(slices: Array, unit_random: float) -> Dictionary:
	var invalid := {"index": -1, "center_angle": 0.0, "start_angle": 0.0, "sweep": 0.0}
	if slices.is_empty() or not is_finite(unit_random):
		return invalid
	var total := 0.0
	for slice: Variant in slices:
		if not slice is Dictionary or not _number(slice.get("weight")) or float(slice.weight) <= 0.0:
			return invalid
		total += float(slice.weight)
	if not is_finite(total) or total <= 0.0:
		return invalid
	var target := clampf(unit_random, 0.0, 1.0) * total
	var accumulated := 0.0
	for i in range(slices.size()):
		var weight := float(slices[i].weight)
		if target < accumulated + weight or i == slices.size() - 1:
			var start := accumulated / total * TAU_VALUE
			var sweep := weight / total * TAU_VALUE
			return {"index": i, "center_angle": start + sweep / 2.0, "start_angle": start, "sweep": sweep}
		accumulated += weight
	return invalid

static func slice_geometry(slices: Array) -> Array:
	# One set of half-open boundaries for drawing and stopped-angle selection.
	var total := 0.0
	for slice: Variant in slices:
		if not slice is Dictionary or not _number(slice.get("weight")) or float(slice.weight) <= 0.0:
			return []
		total += float(slice.weight)
	if not is_finite(total) or total <= 0.0:
		return []
	var result: Array = []
	var accumulated := 0.0
	for i in range(slices.size()):
		var start := accumulated / total * TAU_VALUE
		accumulated += float(slices[i].weight)
		var end := TAU_VALUE if i == slices.size() - 1 else accumulated / total * TAU_VALUE
		result.append({"index": i, "start_angle": start, "end_angle": end, "sweep": end - start, "center_angle": (start + end) * 0.5})
	return result

static func index_at_rotation(slices: Array, rotation_angle: float) -> int:
	if not is_finite(rotation_angle):
		return -1
	var geometry := slice_geometry(slices)
	var pointer_angle := fposmod(-rotation_angle, TAU_VALUE)
	for wedge: Dictionary in geometry:
		if pointer_angle < wedge.end_angle:
			return wedge.index
	return -1

static func _storage_valid(preset: Dictionary) -> bool:
	# Drafts may have blank labels, fewer than two slices or unfinished totals.
	if not preset.get("name") is String or not preset.get("mode") in ["ratio", "percent"]:
		return false
	if not preset.get("slices") is Array or preset.slices.size() > MAX_SLICES:
		return false
	var ids := {}
	for slice: Variant in preset.slices:
		if not slice is Dictionary or not slice.get("id") is String or slice.get("id", "").is_empty() or ids.has(slice.get("id")):
			return false
		ids[slice.id] = true
		if not slice.get("name") is String or not slice.get("color") is String or not Color.html_is_valid(slice.color):
			return false
		if not _number(slice.get("weight")) or float(slice.weight) <= 0.0:
			return false
	var duration: Variant = preset.get("duration_override", null)
	if duration != null and (not _number(duration) or float(duration) < 1.0 or float(duration) > 30.0):
		return false
	var removal: Variant = preset.get("remove_override", null)
	return removal == null or removal is bool

static func _sanitize(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.get("version") != 1 or not raw.get("presets") is Array:
		return {}
	if raw.presets.size() > MAX_PRESETS:
		return {}
	var result := default_data()
	result.presets = []
	result.last_preset_id = ""
	var settings: Variant = raw.get("settings", {})
	if settings is Dictionary:
		if _number(settings.get("duration")):
			result.settings.duration = clampf(float(settings.duration), 1.0, 30.0)
		for key in ["remove_winner", "sound"]:
			if settings.get(key) is bool:
				result.settings[key] = settings[key]
	var preset_ids := {}
	for value: Variant in raw.presets:
		if not value is Dictionary or not value.get("id") is String or value.get("id", "").is_empty() or preset_ids.has(value.get("id")):
			return {}
		if not _storage_valid(value):
			return {}
		preset_ids[value.id] = true
		var preset := {"id": value.id, "name": value.name, "favorite": value.get("favorite", false) if value.get("favorite", false) is bool else false, "physics_enabled": value.get("physics_enabled", false) if value.get("physics_enabled", false) is bool else false, "mode": value.mode, "slices": [], "duration_override": value.get("duration_override", null), "remove_override": value.get("remove_override", null), "history": [], "remaining_ids": []}
		var slice_ids: Array = []
		for slice: Dictionary in value.slices:
			preset.slices.append({"id": slice.id, "name": slice.name, "color": slice.color, "weight": float(slice.weight)})
			slice_ids.append(slice.id)
		var remaining: Variant = value.get("remaining_ids", slice_ids)
		if not remaining is Array:
			return {}
		for id: Variant in remaining:
			if id is String and id in slice_ids and not id in preset.remaining_ids:
				preset.remaining_ids.append(id)
		var history: Variant = value.get("history", [])
		if not history is Array:
			return {}
		for entry: Variant in history:
			if not entry is Dictionary or not entry.get("name") is String or (entry.has("color") and not entry.color is String):
				return {}
			var at: Variant = entry.get("at", "")
			if not (at is String or _number(at)):
				return {}
			preset.history.append(entry.duplicate(true))
		result.presets.append(preset)
	if raw.get("last_preset_id") is String and preset_ids.has(raw.last_preset_id):
		result.last_preset_id = raw.last_preset_id
	return result

static func _read_valid(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	return _sanitize(parser.data)

static func _preserve_corrupt(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	var suffix := str(Time.get_unix_time_from_system()).replace(".", "_")
	return DirAccess.copy_absolute(path, path + ".corrupt-" + suffix)

static func load_data(path: String = "user://state.json") -> Dictionary:
	var data := _read_valid(path)
	if not data.is_empty():
		return data
	if FileAccess.file_exists(path):
		_preserve_corrupt(path)
	var backup := _read_valid(path + ".bak")
	return backup if not backup.is_empty() else default_data()

static func save_data(data: Dictionary, path: String = "user://state.json") -> Error:
	var clean := _sanitize(data)
	if clean.is_empty():
		return ERR_INVALID_DATA
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(clean, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	if _read_valid(temp).is_empty():
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(path):
		var backup_error: Error
		if _read_valid(path).is_empty():
			backup_error = _preserve_corrupt(path)
		else:
			backup_error = DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			return backup_error
	return DirAccess.rename_absolute(temp, path)

static func landing_angle(choice: Dictionary, unit_random: float) -> float:
	# Independent uniform point within the chosen interval. Only a sub-pixel
	# numerical boundary margin is excluded; probability selection is unchanged.
	var start := float(choice.start_angle)
	var sweep := float(choice.sweep)
	var epsilon := minf(sweep * 0.25, maxf(minf(1.0e-10, sweep * 1.0e-6), maxf(1.0, absf(start)) * 1.7763568394002505e-15))
	return start + clampf(unit_random, 0.0, 1.0) * (sweep - 2.0 * epsilon) + epsilon
