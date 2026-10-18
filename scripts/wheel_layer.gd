extends Control
## Viewport-sized in-app modal. Content and nested layers are deliberately separate.
signal confirmed
signal canceled
signal close_requested

static var _open_layers: Array[Control] = []
var title := "":
 set(value):
  title = value
  if is_instance_valid(_heading): _heading.text = value
var dialog_text := "":
 set(value):
  dialog_text = value
  if is_instance_valid(_message):
   _message.text = value
   _message.visible = not value.is_empty()
var ok_button_text := "닫기":
 set(value):
  ok_button_text = value
  if is_instance_valid(_ok): _ok.text = value
var cancel_button_text := "취소":
 set(value):
  cancel_button_text = value
  if is_instance_valid(_cancel): _cancel.text = value
var max_width := 560.0
var min_size := Vector2i(400, 240)
var exclusive := true
var transparent_bg := true
var show_footer := true:
 set(value):
  show_footer = value
  if is_instance_valid(_footer): _footer.visible = value
var is_dropdown := false
var dropdown_anchor := Rect2()
var content: VBoxContainer
var card: PanelContainer
var _heading: Label
var _message: Label
var _scroll: ScrollContainer
var _footer: HBoxContainer
var _ok: Button
var _cancel: Button
var _close: Button
var _opener: WeakRef
var _confirmation := false
var _preferred := Vector2i.ZERO
var _built := false

func _init() -> void:
 visible = false
 mouse_filter = Control.MOUSE_FILTER_STOP
 set_meta("is_layer", true)

func _ready() -> void:
 _build()
 add_to_group("wheel_layers")
 set_as_top_level(true)
 get_viewport().size_changed.connect(layout_card)
 visibility_changed.connect(_visibility_updated)

func _style(fill: Color, radius: int = 12) -> StyleBoxFlat:
 var s := StyleBoxFlat.new()
 s.bg_color = fill
 s.set_corner_radius_all(radius)
 s.set_content_margin_all(12)
 return s

func _button(label_text: String, primary: bool = false) -> Button:
 var b := Button.new()
 b.text = label_text
 b.custom_minimum_size = Vector2(88, 44)
 var normal := _style(Color("087c8c") if primary else Color("f2f3ef"))
 b.add_theme_stylebox_override("normal", normal)
 var hover := normal.duplicate() as StyleBoxFlat
 hover.bg_color = Color("066979") if primary else Color("e6e9e2")
 b.add_theme_stylebox_override("hover", hover)
 b.add_theme_stylebox_override("pressed", hover)
 var focus := _style(Color(0, 0, 0, 0))
 focus.border_color = Color("71806a")
 focus.set_border_width_all(2)
 b.add_theme_stylebox_override("focus", focus)
 for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
  b.add_theme_color_override(key, Color("ffffff") if primary else Color("30352f"))
 b.add_theme_font_size_override("font_size", 15)
 return b

func _build() -> void:
 if _built: return
 _built = true
 var dim := ColorRect.new()
 dim.color = Color(0,0,0,0) if is_dropdown else Color(0.10, 0.12, 0.10, 0.38)
 if is_dropdown:
  dim.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: request_close.call_deferred())
 dim.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(dim)
 dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 card = PanelContainer.new()
 var panel := _style(Color("ffffff"), 22)
 panel.set_content_margin_all(8 if is_dropdown else 22)
 if is_dropdown: panel.set_corner_radius_all(12); panel.border_color = Color("d9dcd6"); panel.set_border_width_all(1)
 panel.shadow_color = Color(0, 0, 0, 0.07 if is_dropdown else 0.14)
 panel.shadow_size = 8 if is_dropdown else 20
 panel.shadow_offset = Vector2(0, 3 if is_dropdown else 7)
 card.add_theme_stylebox_override("panel", panel)
 card.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(card)
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation", 18)
 card.add_child(column)
 var header := HBoxContainer.new()
 header.add_theme_constant_override("separation", 12)
 column.add_child(header)
 header.visible = not is_dropdown
 _heading = Label.new()
 _heading.text = title
 _heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 _heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
 _heading.add_theme_font_size_override("font_size", 21)
 _heading.add_theme_color_override("font_color", Color("2c332b"))
 header.add_child(_heading)
 # Dedicated icon control: no generic text-button padding or icon auto-fit.
 _close = Button.new()
 _close.icon = preload("res://assets/close.svg")
 _close.expand_icon = false
 _close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
 _close.add_theme_constant_override("icon_max_width",18)
 _close.add_theme_constant_override("h_separation",0)
 _close.custom_minimum_size = Vector2(40,40)
 _close.size_flags_horizontal = Control.SIZE_SHRINK_END
 _close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 _close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
  var close_style := _style(Color("fff1f3"),10)
  close_style.set_content_margin_all(8)
  close_style.border_color = Color("efc6cc"); close_style.set_border_width_all(1)
  if state in ["hover","pressed","hover_pressed"]: close_style.bg_color = Color("ffe3e7")
  if state == "disabled": close_style.bg_color = Color("f8eeee")
  if state == "focus": close_style.bg_color = Color.TRANSPARENT; close_style.border_color = Color("b83243")
  _close.add_theme_stylebox_override(state,close_style)
 for state in ["icon_normal_color","icon_hover_color","icon_pressed_color","icon_hover_pressed_color","icon_focus_color","icon_disabled_color"]:
  _close.add_theme_color_override(state,Color.WHITE)
 _close.tooltip_text = "닫기"
 _close.pressed.connect(request_close)
 header.add_child(_close)
 _scroll = ScrollContainer.new()
 _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 _scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
 _scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
 _scroll.follow_focus = true
 column.add_child(_scroll)
 content = VBoxContainer.new()
 content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 content.add_theme_constant_override("separation", 14)
 _scroll.add_child(content)
 _message = Label.new()
 _message.text = dialog_text
 _message.visible = not dialog_text.is_empty()
 _message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 _message.add_theme_font_size_override("font_size", 15)
 _message.add_theme_color_override("font_color", Color("5b6358"))
 content.add_child(_message)
 _footer = HBoxContainer.new()
 _footer.alignment = BoxContainer.ALIGNMENT_END
 _footer.add_theme_constant_override("separation", 10)
 _footer.visible = show_footer
 column.add_child(_footer)
 _cancel = _button(cancel_button_text)
 _cancel.visible = _confirmation
 _cancel.pressed.connect(request_close)
 _footer.add_child(_cancel)
 _ok = _button(ok_button_text, true)
 _ok.pressed.connect(_accept)
 _footer.add_child(_ok)

func add_content(node: Control) -> void:
 _build()
 content.add_child(node)
 node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 _disable_native_menus.call_deferred(node)

func get_ok_button() -> Button:
 _build()
 return _ok

func set_confirmation(enabled: bool = true) -> void:
 _confirmation = enabled
 _build()
 _cancel.visible = enabled

func popup_centered(target: Vector2i = Vector2i.ZERO) -> void:
 _build()
 if not is_inside_tree(): return
 if not visible:
  var owner := get_viewport().gui_get_focus_owner()
  if is_instance_valid(owner): _opener = weakref(owner)
 _open_layers.erase(self)
 _open_layers.append(self)
 z_as_relative = false
 z_index = 100 + _open_layers.size() * 2
 _preferred = target
 show()
 layout_card()
 _settle_layout.call_deferred()
 _focus_initial.call_deferred()
 _disable_native_menus.call_deferred(content)

func layout_card(target: Vector2i = Vector2i.ZERO) -> void:
 if not is_inside_tree() or not _built: return
 if target != Vector2i.ZERO: _preferred = target
 position = Vector2.ZERO
 size = get_viewport_rect().size
 var available := Vector2(maxf(1, size.x - 32), maxf(1, size.y - 48))
 var requested := Vector2(_preferred if _preferred != Vector2i.ZERO else min_size)
 var width := minf(minf(max_width, available.x), maxf(320, requested.x))
 # The scroll viewport never imposes its content's minimum height on the card.
 var chrome := 44.0 + 40.0 + 18.0
 if show_footer: chrome += 44.0 + 18.0
 var natural := chrome
 if _scroll.size.x > 8 and absf(_scroll.size.x - (width - 44)) < 2:
  natural += content.get_combined_minimum_size().y
 var height := minf(available.y, requested.y if _preferred != Vector2i.ZERO else maxf(requested.y, natural))
 card.custom_minimum_size = Vector2.ZERO
 if is_dropdown:
  width = clampf(dropdown_anchor.size.x, 180, minf(560, size.x - 24))
  height = minf(320, maxf(62, content.get_combined_minimum_size().y + 16))
  card.size = Vector2(width, height)
  var origin := dropdown_anchor.position + Vector2(0, dropdown_anchor.size.y + 6)
  if origin.y + height > size.y - 12: origin.y = dropdown_anchor.position.y - height - 6
  card.position = Vector2(clampf(origin.x,12,size.x-width-12),clampf(origin.y,12,size.y-height-12))
 else:
  card.size = Vector2(width, height)
  card.position = (size - card.size) * 0.5

func _settle_layout() -> void:
 if not is_inside_tree(): return
 await get_tree().process_frame
 if is_inside_tree() and visible: layout_card()

func _accept() -> void:
 hide()
 confirmed.emit()

func request_close() -> void:
 if not visible: return
 hide()
 close_requested.emit()
 canceled.emit()

func _visibility_updated() -> void:
 if not visible:
  _open_layers.erase(self)
  _restore_weak_focus.call_deferred(_opener)
  _opener = null

func _exit_tree() -> void:
 _open_layers.erase(self)
 _restore_weak_focus.call_deferred(_opener)
 _opener = null

static func _restore_weak_focus(reference: WeakRef) -> void:
 if reference == null: return
 var previous = reference.get_ref()
 if is_instance_valid(previous) and previous.is_inside_tree() and previous.is_visible_in_tree():
  previous.grab_focus()

func _focus_initial() -> void:
 if not is_inside_tree(): return
 await get_tree().process_frame
 if not is_inside_tree() or not visible or not _is_topmost(): return
 var choices: Array[Control] = []
 _collect_focus(content, choices)
 if not choices.is_empty(): choices[0].grab_focus()
 else: _ok.grab_focus()
 _scroll.scroll_vertical = 0

func _is_topmost() -> bool:
 while not _open_layers.is_empty() and (not is_instance_valid(_open_layers.back()) or not _open_layers.back().is_visible_in_tree()):
  _open_layers.pop_back()
 return not _open_layers.is_empty() and _open_layers.back() == self

func _collect_focus(node: Node, result: Array[Control]) -> void:
 if node is Control:
  if not node.is_visible_in_tree(): return
  if node.focus_mode == Control.FOCUS_ALL and not (node is BaseButton and node.disabled): result.append(node)
 for child in node.get_children(true): _collect_focus(child, result)

func _input(event: InputEvent) -> void:
 if not visible or not _is_topmost(): return
 if is_dropdown and event is InputEventScreenTouch and event.pressed and not card.get_global_rect().has_point(event.position):
  get_viewport().set_input_as_handled()
  request_close.call_deferred()
  return
 if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
  var choices: Array[Control] = []
  _collect_focus(card, choices)
  if not choices.is_empty():
   var current := choices.find(get_viewport().gui_get_focus_owner())
   var step := -1 if event.shift_pressed else 1
   choices[posmod(current + step, choices.size())].grab_focus()
  get_viewport().set_input_as_handled()

func _disable_native_menus(node: Node) -> void:
 if not is_instance_valid(node): return
 if node is LineEdit: node.context_menu_enabled = false
 for child in node.get_children(true): _disable_native_menus(child)
