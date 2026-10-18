extends Button
## Consistent in-app selector; intentionally avoids platform PopupMenu styling.
signal item_selected(index: int)
var selected := -1
var fit_to_longest_item := false
var items: Array[String] = []
const Layer = preload("res://scripts/wheel_layer.gd")
var popup: Control
var chevron: TextureRect

func _ready() -> void:
 alignment = HORIZONTAL_ALIGNMENT_LEFT
 clip_text = true
 custom_minimum_size.y = maxf(custom_minimum_size.y, 46)
 add_theme_constant_override("outline_size", 0)
 for key in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]: add_theme_color_override(key, Color("30362f"))
 var field := StyleBoxFlat.new()
 field.bg_color = Color("f7f7f5")
 field.set_corner_radius_all(12)
 field.border_color = Color("d6d9d3"); field.set_border_width_all(1)
 field.content_margin_left = 16; field.content_margin_right = 42
 field.content_margin_top = 12; field.content_margin_bottom = 12
 add_theme_stylebox_override("normal", field)
 var hover := field.duplicate() as StyleBoxFlat; hover.bg_color = Color("eceeeb")
 add_theme_stylebox_override("hover", hover)
 var focus := field.duplicate() as StyleBoxFlat; focus.bg_color = Color(0,0,0,0); focus.border_color = Color("667060"); focus.set_border_width_all(1)
 add_theme_stylebox_override("focus", focus)
 chevron = TextureRect.new(); chevron.texture = preload("res://assets/chevron.svg"); chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
 chevron.anchor_left = 1; chevron.anchor_right = 1; chevron.anchor_top = .5; chevron.anchor_bottom = .5
 chevron.offset_left = -32; chevron.offset_right = -12; chevron.offset_top = -10; chevron.offset_bottom = 10
 add_child(chevron)
 pressed.connect(open_choices)
 tree_exiting.connect(func(): if is_instance_valid(popup): popup.queue_free())

func add_item(value: String) -> void:
 items.append(value)
 if selected < 0: select(0)

func select(index: int) -> void:
 selected = index
 text = items[index] if index >= 0 and index < items.size() else ""

func clear() -> void:
 items.clear(); selected = -1; text = ""

func set_item_text(index: int, value: String) -> void:
 items[index] = value
 if selected == index: text = value

func get_item_text(index: int) -> String:
 return items[index]

func get_item_count() -> int:
 return items.size()

func open_choices() -> void:
 if disabled or items.is_empty(): return
 if is_instance_valid(popup): popup.queue_free()
 popup = Layer.new(); popup.is_dropdown = true; popup.dropdown_anchor = get_global_rect(); popup.show_footer = false
 get_tree().current_scene.add_child(popup)
 var panel := StyleBoxFlat.new(); panel.bg_color = Color("ffffff"); panel.set_corner_radius_all(12); panel.set_content_margin_all(8)
 var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
 popup.add_content(scroll)
 var list := VBoxContainer.new(); list.add_theme_constant_override("separation", 3); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(list)
 var width := clampf(size.x, 180, minf(560, get_viewport_rect().size.x - 24))
 for i in range(items.size()):
  var option := Button.new(); option.text = ("✓  " if i == selected else "    ") + items[i]; option.alignment = HORIZONTAL_ALIGNMENT_LEFT; option.clip_text = true
  option.custom_minimum_size = Vector2(width - 16, 46)
  var normal := panel.duplicate() as StyleBoxFlat; normal.set_border_width_all(0); normal.bg_color = Color("eceeea") if i == selected else Color("ffffff"); normal.set_corner_radius_all(11); normal.set_content_margin_all(12)
  option.add_theme_stylebox_override("normal", normal)
  var focus := normal.duplicate() as StyleBoxFlat; focus.bg_color = Color("e7e9e5"); focus.set_border_width_all(0)
  option.add_theme_stylebox_override("focus", focus)
  var hover := normal.duplicate() as StyleBoxFlat; hover.bg_color = Color("f3f4f1"); option.add_theme_stylebox_override("hover", hover)
  option.add_theme_color_override("font_focus_color", Color("26332b")); option.add_theme_color_override("font_hover_color", Color("26332b"))
  option.add_theme_color_override("font_color", Color("26332b"))
  option.pressed.connect(func(): choose(i))
  list.add_child(option)
 scroll.custom_minimum_size = Vector2(width - 16, minf(320, items.size() * 49))
 popup.canceled.connect(popup.queue_free)
 popup.popup_centered(Vector2i(440, mini(500, items.size() * 52 + 100)))
 if selected >= 0: list.get_child(selected).grab_focus.call_deferred()

func choose(index: int) -> void:
 select(index)
 if is_instance_valid(popup): popup.hide(); popup.queue_free()
 _emit_choice.call_deferred(index)

func _emit_choice(index: int) -> void:
 if is_inside_tree(): item_selected.emit(index)
