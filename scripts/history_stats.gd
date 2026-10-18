extends RefCounted
## Observed results only. No dependence on live slices, weights or remaining items.
const NEUTRAL_COLOR := Color("a8b1ad")

static func stored_color(entry: Dictionary) -> Color:
 var value: Variant = entry.get("color", "")
 return Color(value) if value is String and Color.html_is_valid(value) else NEUTRAL_COLOR

static func summarize(history: Array) -> Dictionary:
 var by_key := {}
 var groups: Array[Dictionary] = []
 var total := 0
 var legacy_count := 0
 for index in range(history.size() - 1, -1, -1):
  var entry: Variant = history[index]
  if not entry is Dictionary or not entry.get("name") is String: continue
  total += 1
  var raw_id: Variant = entry.get("slice_id", "")
  var stable_id: String = raw_id if raw_id is String and not raw_id.is_empty() else ""
  var legacy := stable_id.is_empty()
  if legacy: legacy_count += 1
  var key := JSON.stringify(["legacy", entry.name] if legacy else ["id", stable_id])
  var raw_color: Variant = entry.get("color", "")
  var valid_color: bool = raw_color is String and Color.html_is_valid(raw_color)
  if not by_key.has(key):
   var group := {"key": key, "slice_id": stable_id, "legacy": legacy, "name": str(entry.name), "display_name": str(entry.name), "color": stored_color(entry), "count": 0, "percentage": 0.0, "latest_index": index, "_has_color": valid_color}
   by_key[key] = group
   groups.append(group)
  var group: Dictionary = by_key[key]
  group.count += 1
  # Search only this namespace for the newest valid stored color, never live slices.
  if not group._has_color and valid_color:
   group.color = Color(raw_color)
   group._has_color = true
 groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
  return a.count > b.count if a.count != b.count else a.latest_index > b.latest_index)
 var name_counts := {}
 for group in groups: name_counts[group.name] = int(name_counts.get(group.name, 0)) + 1
 var ids_by_name := {}
 for group in groups:
  if not group.legacy:
   if not ids_by_name.has(group.name): ids_by_name[group.name] = []
   ids_by_name[group.name].append(group.slice_id)
 for name in ids_by_name: ids_by_name[name].sort()
 for group in groups:
  group.percentage = float(group.count) * 100.0 / total if total > 0 else 0.0
  if int(name_counts[group.name]) > 1:
   if group.legacy: group.display_name = "%s · 이전 기록" % group.name
   else:
    group.display_name = "%s · 항목 %d" % [group.name, ids_by_name[group.name].find(group.slice_id) + 1]
  group.erase("_has_color")
 return {"total": total, "groups": groups, "legacy_count": legacy_count}
