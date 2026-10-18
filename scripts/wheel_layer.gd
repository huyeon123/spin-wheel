extends Control
## Viewport-sized in-app modal. Content and nested layers are deliberately separate.
const SafeLayout = preload("res://scripts/safe_layout.gd")
signal confirmed
signal canceled
signal close_requested

const ENTER_SECONDS := 0.18
const EXIT_SECONDS := 0.14
const TRAVEL_PIXELS := 10.0
## Injectable accessibility preference: host/platform integration may set this.
## Godot 4.6 has no cross-platform native reduced-motion preference API.
static var reduced_motion := false
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
## Disable for browse-first editors so opening never summons a mobile keyboard.
var focus_content_on_open := true
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
var _transition: Tween
var _closing := false
var _transition_id := 0
var _rest_position := Vector2.ZERO
var _motion_offset := 0.0:
 set(value):
  _motion_offset = value
  if is_instance_valid(card): card.position = _rest_position + Vector2(0, value)
var _exit_blocker: Control

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
 card.focus_mode = Control.FOCUS_CLICK
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
 # Keeps the card inert through exit while the full-screen layer still blocks input.
 _exit_blocker = Control.new()
 _exit_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(_exit_blocker)
 _exit_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 _exit_blocker.hide()

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
 var was_visible := visible
 _stop_transition()
 _closing = false
 _exit_blocker.hide()
 if not visible:
  var owner := get_viewport().gui_get_focus_owner()
  if is_instance_valid(owner): _opener = weakref(owner)
 _open_layers.erase(self)
 _open_layers.append(self)
 for i in range(_open_layers.size()):
  if is_instance_valid(_open_layers[i]):
   _open_layers[i].z_as_relative = false
   _open_layers[i].z_index = 100 + (i + 1) * 2
 _preferred = target
 show()
 if not focus_content_on_open: card.grab_focus()
 layout_card()
 _settle_layout.call_deferred()
 _focus_initial.call_deferred()
 _disable_native_menus.call_deferred(content)
 if reduced_motion:
  modulate.a = 1.0
  _motion_offset = 0.0
 else:
  if not was_visible:
   modulate.a = 0.0
   _motion_offset = TRAVEL_PIXELS
  _transition = create_tween().set_parallel(true)
  _transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
  _transition.tween_property(self, "modulate:a", 1.0, ENTER_SECONDS)
  _transition.tween_property(self, "_motion_offset", 0.0, ENTER_SECONDS)

func layout_card(target: Vector2i = Vector2i.ZERO) -> void:
 if not is_inside_tree() or not _built: return
 if target != Vector2i.ZERO: _preferred = target
 position = Vector2.ZERO
 size = get_viewport_rect().size
 var safe := SafeLayout.safe_rect(self)
 var card_area := SafeLayout.inset_rect(safe, 16, 24)
 var available := card_area.size
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
  var dropdown_area := SafeLayout.inset_rect(safe, 12, 12)
  width = minf(maxf(dropdown_anchor.size.x, 180), minf(560, dropdown_area.size.x))
  height = minf(dropdown_area.size.y, minf(320, maxf(62, content.get_combined_minimum_size().y + 16)))
  card.size = Vector2(width, height)
  var origin := dropdown_anchor.position + Vector2(0, dropdown_anchor.size.y + 6)
  if origin.y + height > dropdown_area.end.y: origin.y = dropdown_anchor.position.y - height - 6
  card.position = Vector2(clampf(origin.x,dropdown_area.position.x,maxf(dropdown_area.position.x,dropdown_area.end.x-card.size.x)),clampf(origin.y,dropdown_area.position.y,maxf(dropdown_area.position.y,dropdown_area.end.y-card.size.y)))
 else:
  card.size = Vector2(width, height)
  card.position = card_area.position + (card_area.size - card.size) * 0.5
 _rest_position = card.position
 card.position = _rest_position + Vector2(0, _motion_offset)
 _keep_focus_visible.call_deferred()

func _keep_focus_visible() -> void:
 if not is_inside_tree() or not visible: return
 await get_tree().process_frame
 if not is_inside_tree() or not visible: return
 var focused := get_viewport().gui_get_focus_owner()
 if is_instance_valid(focused) and content.is_ancestor_of(focused):
  _scroll.ensure_control_visible(focused)

func _settle_layout() -> void:
 if not is_inside_tree(): return
 await get_tree().process_frame
 if is_inside_tree() and visible: layout_card()

func _stop_transition() -> void:
 _transition_id += 1
 if is_instance_valid(_transition): _transition.kill()
 _transition = null

## Callers that switch or destroy a layer must defer that action until exit completes.
func dismiss(after_close: Callable = Callable()) -> void:
 if _closing: return
 if not visible:
  if after_close.is_valid(): after_close.call_deferred()
  return
 _stop_transition()
 _closing = true
 _exit_blocker.show()
 card.grab_focus()
 var token := _transition_id
 if reduced_motion:
  _finish_dismiss.call_deferred(token, after_close)
  return
 _transition = create_tween().set_parallel(true)
 _transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
 _transition.tween_property(self, "modulate:a", 0.0, EXIT_SECONDS)
 _transition.tween_property(self, "_motion_offset", TRAVEL_PIXELS, EXIT_SECONDS)
 _transition.chain().tween_callback(_finish_dismiss.bind(token, after_close))

func _finish_dismiss(token: int, after_close: Callable) -> void:
 if token != _transition_id or not _closing: return
 _closing = false
 hide()
 _deliver_dismiss.call_deferred(_transition_id, after_close)

func _deliver_dismiss(token: int, after_close: Callable) -> void:
 if token != _transition_id or visible: return
 if after_close.is_valid(): after_close.call()

func _accept() -> void:
 dismiss(func(): confirmed.emit())

func request_close() -> void:
 if not visible or _closing: return
 dismiss(func():
  close_requested.emit()
  canceled.emit())

func _visibility_updated() -> void:
 if not visible:
  _stop_transition()
  _closing = false
  _open_layers.erase(self)
  _restore_weak_focus.call_deferred(_opener)
  _opener = null

func _exit_tree() -> void:
 _stop_transition()
 _open_layers.erase(self)
 _restore_weak_focus.call_deferred(_opener)
 _opener = null

static func _restore_weak_focus(reference: WeakRef) -> void:
 if reference == null: return
 var previous = reference.get_ref()
 if is_instance_valid(previous) and previous.is_inside_tree() and previous.is_visible_in_tree():
  # A newer modal owns focus; never restore behind it during a layer switch/reopen.
  if not _open_layers.is_empty():
   var top: Control = _open_layers.back()
   if is_instance_valid(top) and top.is_visible_in_tree() and previous != top and not top.is_ancestor_of(previous): return
  previous.grab_focus()

func _focus_initial() -> void:
 if not is_inside_tree(): return
 var token := _transition_id
 await get_tree().process_frame
 if not is_inside_tree() or not visible or _closing or token != _transition_id or not _is_topmost(): return
 if not focus_content_on_open:
  card.grab_focus()
  _scroll.scroll_vertical = 0
  return
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
 if _closing:
  get_viewport().set_input_as_handled()
  return
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
   var next := (choices.size() - 1 if event.shift_pressed else 0) if current < 0 else posmod(current + step, choices.size())
   choices[next].grab_focus()
  get_viewport().set_input_as_handled()

func _disable_native_menus(node: Node) -> void:
 if not is_instance_valid(node): return
 if node is LineEdit: node.context_menu_enabled = false
 for child in node.get_children(true): _disable_native_menus(child)
