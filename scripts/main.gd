extends Control

const Model = preload("res://scripts/wheel_model.gd")
const Reorder = preload("res://scripts/reorder_handle.gd")
const Layer = preload("res://scripts/wheel_layer.gd")
const Select = preload("res://scripts/wheel_select.gd")
const Wheel = preload("res://scripts/wheel_canvas.gd")
const PALETTE = ["#a89bea", "#ffcc75", "#7ad3b9", "#f69ca9", "#83b9ed", "#d8b1df", "#a8d584", "#f4b18c"]
var data: Dictionary
var preset: Dictionary
var busy := false
var wheel: Control
var body: GridContainer
var editor: VBoxContainer
var selectors: Button
var result: Label
var status: Label
var spin_button: Button
var duration_label: Label
var preset_name: Label
var content_scroll: ScrollContainer
var audio: AudioStreamPlayer
var font := preload("res://assets/NotoSansKR.otf")
var current_rotation := 0.0
var tween: Tween
var rng := RandomNumberGenerator.new()
var dirty := false
var save_timer: Timer
var history_dialog: Control
var narrow := false
var editor_dialog: Control
var manager_dialog: Control
var main_selector: Button
var dragging := false
var drag_pointer := -2
var drag_last_angle := 0.0
var drag_last_time := 0.0
var drag_distance := 0.0
var drag_velocity := 0.0
var spin_start := 0.0
var spin_distance := 0.0
var spin_initial_velocity := 0.0
var spin_seconds := 6.0
var scrim: ColorRect
var editor_opener: Control
var stage_spacer: Control
var wheel_aspect: AspectRatioContainer

func _ready() -> void:
 get_tree().quit_on_go_back = false
 child_entered_tree.connect(_register_layer)
 Engine.max_fps = 60
 OS.low_processor_usage_mode = true
 rng.randomize()
 data = Model.load_data()
 if data.presets.is_empty(): data = Model.default_data()
 preset = data.presets[0]
 for p in data.presets:
  if p.id == data.last_preset_id: preset = p
 _theme()
 audio = AudioStreamPlayer.new()
 add_child(audio)
 save_timer = Timer.new()
 save_timer.one_shot = true
 save_timer.wait_time = .35
 save_timer.timeout.connect(_save)
 add_child(save_timer)
 _build()
 resized.connect(_responsive)
 _responsive()
 if "--smoke" in OS.get_cmdline_user_args():
  await get_tree().process_frame
  print("UI_SMOKE_OK")
  get_tree().quit()
 if "--screenshot" in OS.get_cmdline_user_args():
  await get_tree().process_frame
  await get_tree().process_frame
  if "--editor-shot" in OS.get_cmdline_user_args(): _open_editor()
  if "--settings-shot" in OS.get_cmdline_user_args(): _settings()
  if "--color-shot" in OS.get_cmdline_user_args(): _pick_color(preset.slices[0])
  if "--history-shot" in OS.get_cmdline_user_args(): _history()
  if "--result-shot" in OS.get_cmdline_user_args():
   preset.duration_override = 1.0; data.settings.sound = false; _spin(); await tween.finished
  if "--selector-shot" in OS.get_cmdline_user_args():
   preset.favorite = true
   for name in ["점심 메뉴", "주말에 할 일"]:
    var sample: Dictionary = Model.default_data().presets[0].duplicate(true); sample.id = _id(); sample.name = name; data.presets.append(sample)
   _preset_manager()
  await get_tree().create_timer(1.5).timeout
  get_viewport().get_texture().get_image().save_png("res://build/screenshot.png")
  get_tree().quit()

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
  _cancel_drag()
 if what == NOTIFICATION_WM_GO_BACK_REQUEST:
  if not _close_top_layer():
   _save()
   get_tree().quit()
 if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
  if data != null: _save()

func _theme() -> void:
 var t := Theme.new()
 t.default_font = font
 t.default_font_size = 16
 t.set_icon("checked","CheckButton",load("res://assets/toggle-on.svg")); t.set_icon("unchecked","CheckButton",load("res://assets/toggle-off.svg"))
 t.set_color("font_placeholder_color", "LineEdit", Color("747b74"))
 t.set_color("caret_color", "LineEdit", Color("29302c"))
 t.set_color("font_color", "Label", Color("29302c"))
 for cls in ["Button", "OptionButton", "LineEdit", "SpinBox", "CheckButton", "CheckBox"]:
  t.set_color("font_color", cls, Color("29302c"))
  t.set_color("font_hover_color", cls, Color("46594b"))
  t.set_color("font_focus_color", cls, Color("29302c"))
  t.set_color("font_pressed_color", cls, Color("29302c"))
  t.set_color("font_hover_pressed_color", cls, Color("29302c"))
  t.set_color("font_disabled_color", cls, Color("737c74"))
 for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
  var s := StyleBoxFlat.new()
  s.bg_color = Color("f6f6f4") if state == "normal" else Color("e9ebe8")
  if state == "disabled": s.bg_color = Color("eceeea")
  s.set_corner_radius_all(12)
  s.content_margin_left = 16; s.content_margin_right = 16
  s.content_margin_top = 11; s.content_margin_bottom = 11
  s.border_color = Color("d9dcd6")
  s.set_border_width_all(1)
  t.set_stylebox(state, "Button", s)
  t.set_stylebox(state, "OptionButton", s)
  t.set_stylebox(state, "LineEdit", s)
  t.set_stylebox(state, "CheckBox", s)
  t.set_stylebox(state, "CheckButton", s)
 t.set_stylebox("read_only", "LineEdit", t.get_stylebox("disabled","LineEdit"))
 t.set_color("font_uneditable_color","LineEdit",Color("747d76"))
 var divider := StyleBoxLine.new(); divider.color = Color("e3e7e2"); divider.thickness = 1; t.set_stylebox("separator","HSeparator",divider)
 var panel := StyleBoxFlat.new()
 panel.bg_color = Color.WHITE
 panel.set_corner_radius_all(28)
 panel.content_margin_left = 24; panel.content_margin_right = 24
 panel.content_margin_top = 24; panel.content_margin_bottom = 24
 t.set_stylebox("panel", "PanelContainer", panel)
 theme = t

func _label(text: String, fs := 16) -> Label:
 var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", fs)
 return l

func _button(text: String, action: Callable) -> Button:
 var b := Button.new(); b.text = text; b.pressed.connect(func(): action.call_deferred()); b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 b.custom_minimum_size.y = 46
 return b

func _row() -> HBoxContainer:
 var r := HBoxContainer.new(); r.add_theme_constant_override("separation", 10)
 return r

func _build() -> void:
 var backdrop := TextureRect.new(); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var gradient := Gradient.new(); gradient.set_color(0,Color("f5f3ef")); gradient.set_color(1,Color("f5f3ef"))
 var texture := GradientTexture2D.new(); texture.gradient = gradient; texture.fill_from = Vector2(0,0); texture.fill_to = Vector2(1,1); texture.width = 256; texture.height = 256
 backdrop.texture = texture; backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; backdrop.stretch_mode = TextureRect.STRETCH_SCALE; add_child(backdrop)
 var margin := MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
 add_child(margin)
 content_scroll = ScrollContainer.new()
 content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
 margin.add_child(content_scroll)
 var outer := VBoxContainer.new(); outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 outer.add_theme_constant_override("separation", 14); content_scroll.add_child(outer)
 var header := _row(); outer.add_child(header)
 var left_spacer := Control.new(); left_spacer.custom_minimum_size.x = 48; header.add_child(left_spacer)
 var center := CenterContainer.new(); center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(center)
 main_selector = _button("", _preset_manager); main_selector.clip_text = true; main_selector.custom_minimum_size.x = 220; main_selector.tooltip_text = "프리셋 관리"; main_selector.accessibility_name = "프리셋 관리"; center.add_child(main_selector)
 var gear := _button("", _settings); gear.icon = load("res://assets/settings.svg"); gear.custom_minimum_size = Vector2(48,48); gear.tooltip_text = "설정"; header.add_child(gear)
 for property in gear.get_property_list():
  if property.name == "accessibility_name": gear.set("accessibility_name", "설정")
 var last := PanelContainer.new(); last.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; last.custom_minimum_size.y = 48; var result_style := theme.get_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat; result_style.content_margin_top = 14; result_style.content_margin_bottom = 14; last.add_theme_stylebox_override("panel", StyleBoxEmpty.new()); outer.add_child(last)
 var lr := _row(); last.add_child(lr)
 result = _label("첫 번째 행운을 돌려보세요", 20)
 result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; lr.add_child(result)
 stage_spacer = Control.new(); outer.add_child(stage_spacer)
 body = GridContainer.new(); body.columns = 1; body.add_theme_constant_override("h_separation", 24); body.add_theme_constant_override("v_separation", 24); outer.add_child(body)
 var stage := PanelContainer.new(); var clear := StyleBoxEmpty.new(); stage.add_theme_stylebox_override("panel", clear); stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_child(stage)
 var stage_box := VBoxContainer.new(); stage_box.add_theme_constant_override("separation", 8); stage.add_child(stage_box)
 var eyebrow := _label("TODAY’S LITTLE LUCK", 12); eyebrow.add_theme_color_override("font_color", Color("80749e")); eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; stage_box.add_child(eyebrow); eyebrow.hide()
 preset_name = _label(preset.name, 25); preset_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; preset_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; stage_box.add_child(preset_name); preset_name.hide()
 var aspect := AspectRatioContainer.new(); wheel_aspect = aspect; aspect.ratio = 1; aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL; aspect.custom_minimum_size = Vector2(240,300); stage_box.add_child(aspect)
 var wheel_holder := Control.new(); aspect.add_child(wheel_holder)
 wheel = Wheel.new(); wheel.font = font; wheel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); wheel_holder.add_child(wheel)
 var pointer := TextureRect.new(); pointer.texture = load("res://assets/pointer.svg"); pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE; pointer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; pointer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; pointer.anchor_left = .5; pointer.anchor_right = .5; pointer.offset_left = -16; pointer.offset_right = 16; pointer.offset_top = -2; pointer.offset_bottom = 30; wheel_holder.add_child(pointer)
 spin_button = _button("돌리기", _spin); spin_button.tooltip_text = "돌리기 (Space)"; spin_button.custom_minimum_size = Vector2(56,48); spin_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; spin_button.add_theme_font_size_override("font_size", 21)
 spin_button.custom_minimum_size = Vector2(360,56); _accent_button(spin_button)
 status = _label("", 14); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; stage_box.add_child(status)
 duration_label = _label("", 13); duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; stage_box.add_child(duration_label); duration_label.hide()
 stage_box.add_child(spin_button)
 var action_gap := Control.new(); action_gap.custom_minimum_size.y = 16; stage_box.add_child(action_gap)
 var controls := _row(); controls.add_theme_constant_override("separation",28); controls.alignment = BoxContainer.ALIGNMENT_CENTER; stage_box.add_child(controls)
 controls.add_child(_icon_button("res://assets/restart.svg", "라운드 복원", _reset_round))
 controls.add_child(_icon_button("res://assets/edit.svg", "룰렛 편집", _open_editor))
 controls.add_child(_icon_button("res://assets/history.svg", "결과 기록", _history))
 editor_dialog = Layer.new(); editor_dialog.theme = theme; editor_dialog.title = "룰렛 편집"; editor_dialog.max_width = 760; editor_dialog.show_footer = false; editor_dialog.ok_button_text = "닫기"; editor_dialog.exclusive = true; add_child(editor_dialog)
 editor_dialog.confirmed.connect(_close_editor); editor_dialog.canceled.connect(_close_editor)
 editor = VBoxContainer.new(); editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL; editor.add_theme_constant_override("separation", 16); editor_dialog.add_content(editor)
 _refresh_editor(); _refresh_wheel(); _refresh_result()
 editor_dialog.hide()

func _responsive() -> void:
 if body == null: return
 main_selector.custom_minimum_size.x = clampf(size.x - 180, 180, 440)
 spin_button.custom_minimum_size.x = minf(360, size.x - 80)
 narrow = size.x < 880
 body.columns = 1
 wheel_aspect.custom_minimum_size.y = 400 if narrow else 430
 stage_spacer.custom_minimum_size.y = clampf((size.y - wheel_aspect.custom_minimum_size.y - 260) / 8, 12, 40)
 if result != null: _refresh_result()
 if editor_dialog.visible: _size_editor()

func _size_editor() -> void:
 editor_dialog.layout_card(Vector2i(760, 720))

func _open_editor() -> void:
 if busy: return
 editor_opener = get_viewport().gui_get_focus_owner()
 _refresh_editor()
 _size_editor()
 editor_dialog.popup_centered(Vector2i(760, 720))

func _close_editor() -> void:
 _commit_inputs(editor)
 editor_dialog.hide()
 if is_instance_valid(editor_opener) and editor_opener.is_inside_tree(): editor_opener.grab_focus.call_deferred()
 _save()
 _refresh_wheel()

func _select_preset(i: int) -> void:
 if busy: return
 preset = data.presets[i]; current_rotation = 0; wheel.rotation = 0
 _refresh_editor(); _refresh_wheel(); _refresh_result()

func _refresh_picker() -> void:
 main_selector.text = str(preset.name)
 main_selector.disabled = busy

func _refresh_result() -> void:
 result.text = str(preset.history.back().name) if not preset.history.is_empty() else ""
 result.custom_minimum_size.x = clampf(font.get_string_size(result.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 8, 80, maxf(80, size.x - 112))
 result.get_parent().get_parent().visible = true

func _refresh_editor() -> void:
 _refresh_picker()
 for child in editor.get_children(): child.queue_free(); editor.remove_child(child)
 selectors = main_selector
 editor.add_child(_label("이름", 13))
 var name_input := LineEdit.new(); name_input.context_menu_enabled = false; name_input.text = preset.name; name_input.placeholder_text = "룰렛 이름"; name_input.max_length = 40; name_input.editable = not busy
 name_input.text_changed.connect(func(value): preset.name = value; preset_name.text = value; _refresh_picker(); _changed())
 editor.add_child(name_input)
 var modes := _row(); editor.add_child(modes)
 var group := ButtonGroup.new()
 for i in range(2):
  var radio := CheckBox.new(); radio.text = "비율로 정하기" if i == 0 else "백분율로 정하기"; radio.button_group = group; radio.button_pressed = (preset.mode == "ratio") == (i == 0); radio.disabled = busy
  radio.add_theme_icon_override("radio_checked",load("res://assets/radio-on.svg")); radio.add_theme_icon_override("radio_unchecked",load("res://assets/radio-off.svg"))
  radio.size_flags_horizontal = Control.SIZE_EXPAND_FILL; radio.custom_minimum_size.y = 44; modes.add_child(radio)
  if radio.button_pressed: _accent_button(radio, true)
  radio.pressed.connect(func(): _change_mode.call_deferred(i))
 var equalize := _button("균등 분배", _equalize); equalize.size_flags_horizontal = Control.SIZE_SHRINK_END; equalize.custom_minimum_size.x = 160; equalize.disabled = busy; editor.add_child(equalize)
 var has_fraction := false
 for slice in preset.slices: has_fraction = has_fraction or float(slice.weight) != floorf(float(slice.weight))
 if has_fraction:
  var legacy := _label("이전 소수 값 유지 중 · 균등 분배 또는 정수 수정으로 변경",12); legacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; editor.add_child(legacy)
 var note := _label("이름 · 색상 · 정수 가중치", 13); note.add_theme_color_override("font_color", Color("7f879d")); editor.add_child(note)
 for i in range(preset.slices.size()): _slice_row(i)
 var plus := _button("항목 추가", _add_slice); _accent_button(plus); plus.disabled = busy or preset.slices.size() >= 40; editor.add_child(plus)
 var info := _label("편집 내용은 자동 저장됩니다.\n항목을 편집하면 현재 라운드가 복원됩니다.", 12); info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info.add_theme_color_override("font_color", Color("81899b")); editor.add_child(info)
 _editor_preset_settings(editor)
 _lock_buttons(editor, busy)

func _slice_row(index: int) -> void:
 var s: Dictionary = preset.slices[index]
 var r := _row(); r.add_theme_constant_override("separation",8); r.set_meta("row_index",index); editor.add_child(r)
 var handle := Reorder.new(); handle.disabled = busy; handle.caption = str(s.name); handle.swatch_color = Color(s.color); r.add_child(handle); handle.configure(editor, r, index, editor_dialog._scroll)
 handle.reordered.connect(_reorder_slices)
 var color := _button("", func(): _pick_color(s)); color.custom_minimum_size = Vector2(38,44); color.disabled = busy; color.tooltip_text = "칸 색상"; r.add_child(color)
 var swatch := StyleBoxFlat.new(); swatch.bg_color = Color(s.color); swatch.set_corner_radius_all(12); color.add_theme_stylebox_override("normal",swatch); color.add_theme_stylebox_override("hover",swatch)
 var name_edit := LineEdit.new(); name_edit.context_menu_enabled = false; name_edit.text = s.name; name_edit.max_length = 40; name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; name_edit.custom_minimum_size.x = 70; name_edit.editable = not busy; r.add_child(name_edit)
 name_edit.text_changed.connect(func(value): s.name = value; _definition_changed())
 var weight := LineEdit.new(); weight.context_menu_enabled = false; weight.text = _weight_text(float(s.weight)); weight.custom_minimum_size.x = 70; weight.max_length = 24; weight.editable = not busy; weight.tooltip_text = "양의 정수 입력"; r.add_child(weight)
 weight.text_changed.connect(func(value):
  if _set_integer_weight(s, value, preset.mode): weight.remove_theme_color_override("font_color"); _definition_changed()
  else: weight.add_theme_color_override("font_color",Color("b03b3b")); weight.tooltip_text = "정수만 입력할 수 있습니다. 기존 값은 유지됩니다.")
 weight.focus_exited.connect(func(): weight.text = _weight_text(float(s.weight)); weight.remove_theme_color_override("font_color"))

 var remove := _button("×", func():
  preset.slices.remove_at(index); _definition_changed(); _refresh_editor())
 _danger_button(remove)
 remove.custom_minimum_size = Vector2(44,44); remove.disabled = busy or preset.slices.size() <= 2; r.add_child(remove)
 var safe_inset := Control.new(); safe_inset.custom_minimum_size.x = 10; r.add_child(safe_inset)

func _lock_buttons(node: Node, locked: bool) -> void:
 if not locked: return
 for child in node.get_children():
  if child is BaseButton: child.disabled = true
  if child is LineEdit: child.editable = false
  _lock_buttons(child, locked)

func _change_mode(index: int) -> void:
 if busy: return
 var target := "percent" if index == 1 else "ratio"
 if target == preset.mode: return
 if target == "percent" and preset.slices.size() > 100:
  _message("균등 분배", "양의 정수 백분율은 최대 100개 항목에만 분배할 수 있습니다."); _refresh_editor(); return
 preset.mode = target
 _equalize()

func _integer_percent_weights(slices: Array) -> Array:
 if slices.is_empty() or slices.size() > 100: return []
 var total := 0.0
 for s in slices: total += float(s.weight)
 if total <= 0: return []
 var result: Array = []
 var fractions: Array = []
 var assigned := 0
 for s in slices:
  var quota := float(s.weight) / total * 100
  var base := maxi(1, int(floor(quota)))
  result.append(base); fractions.append(quota - base); assigned += base
 while assigned > 100:
  var largest := 0
  for i in range(result.size()):
   if result[i] > result[largest]: largest = i
  result[largest] -= 1; assigned -= 1
 while assigned < 100:
  var best := 0
  for i in range(fractions.size()):
   if fractions[i] > fractions[best]: best = i
  result[best] += 1; fractions[best] = -1000.0; assigned += 1
 return result

func _add_slice() -> void:
 if busy: return
 var i: int = preset.slices.size()
 preset.slices.append({"id": _id(), "name": "항목 " + str(i+1), "color": PALETTE[i % PALETTE.size()], "weight": 1.0})
 _definition_changed(); _refresh_editor()

func _id() -> String:
 return str(Time.get_unix_time_from_system()) + "_" + str(rng.randi())

func _definition_changed() -> void:
 preset.remaining_ids = []
 for s in preset.slices: preset.remaining_ids.append(s.id)
 current_rotation = 0; wheel.rotation = 0
 _changed(); _refresh_wheel()

func _changed() -> void:
 dirty = true; save_timer.start()

func _save() -> void:
 var err: int = Model.save_data(data)
 dirty = err != OK
 if err != OK and status != null:
  status.text = "저장하지 못했어요. 저장 공간을 확인해 주세요."
  status.show()

func _refresh_wheel() -> void:
 wheel.slices = Model.active_slices(preset); wheel.queue_redraw()
 preset_name.text = preset.name
 var error: String = Model.validate_preset(preset)
 spin_button.disabled = busy or not error.is_empty() or wheel.slices.size() < 2
 if busy: status.text = ""
 elif not error.is_empty(): status.text = error
 elif wheel.slices.size() < 2: status.text = "항목이 1개 남았어요. 라운드를 복원해 주세요."
 else: status.text = ""
 status.visible = not status.text.is_empty()
 duration_label.text = "회전 %.1f초 · 당첨 항목 %s" % [_duration(), "제외" if _remove_winner() else "유지"]

func _duration() -> float:
 return float(data.settings.duration if preset.duration_override == null else preset.duration_override)

func _remove_winner() -> bool:
 return bool(data.settings.remove_winner if preset.remove_override == null else preset.remove_override)

func _spin(direction: float = 1.0, release_velocity: float = 12.0) -> void:
 if _has_layer(): return
 if busy or not Model.validate_preset(preset).is_empty(): return
 var slices: Array = Model.active_slices(preset)
 if slices.size() < 2: return
 var choice: Dictionary = Model.choose(slices, rng.randf())
 if choice.index < 0: return
 var winner: Dictionary = slices[choice.index].duplicate(true)
 busy = true
 data.last_preset_id = preset.id
 _save(); _refresh_editor(); _refresh_wheel()
 OS.low_processor_usage_mode = false
 spin_start = wheel.rotation
 spin_seconds = _duration()
 var sign_value := 1.0 if direction >= 0 else -1.0
 var speed := clampf(absf(release_velocity), .6, 40.0)
 var alignment := fposmod(-float(choice.center_angle) - spin_start, TAU) if sign_value > 0 else fposmod(spin_start + float(choice.center_angle), TAU)
 var turns := maxi(0, int(ceil((speed * spin_seconds / 2.0 - alignment) / TAU)))
 spin_distance = sign_value * (alignment + TAU * turns)
 spin_initial_velocity = sign_value * speed
 var target := spin_start + spin_distance
 _sound(false)
 tween = create_tween()
 tween.tween_method(_animate_spin, 0.0, 1.0, spin_seconds)
 tween.finished.connect(func():
  current_rotation = fposmod(target, TAU); wheel.rotation = current_rotation
  preset.history.append({"name": winner.name, "color": winner.color, "at": Time.get_datetime_string_from_system(false, true)})
  # History deliberately has no automatic trimming: reset is the user's choice.
  if _remove_winner(): preset.remaining_ids.erase(winner.id)
  busy = false; OS.low_processor_usage_mode = true
  _sound(true); _save(); _refresh_editor(); _refresh_result()
  # Hold landed wheel until the next spin/reset. Keep status truthful to next round.
  spin_button.disabled = Model.active_slices(preset).size() < 2
  status.text = "라운드를 복원해 다시 시작하세요." if spin_button.disabled else ""
  status.visible = not status.text.is_empty()
 )
 # Refresh working slices at the next spin, not before the result is visible.
 wheel.slices = slices; wheel.queue_redraw()

func _reset_round() -> void:
 if busy: return
 _definition_changed()

func _new_preset() -> void:
 if busy or data.presets.size() >= Model.MAX_PRESETS: return
 var p: Dictionary = Model.default_data().presets[0].duplicate(true)
 p.id = _id(); p.name = "새 룰렛 " + str(data.presets.size()+1); p.history = []
 data.presets.append(p); preset = p
 _definition_changed(); _refresh_editor(); _refresh_result()

func _delete_preset() -> void:
 if busy or data.presets.size() <= 1: return
 _confirm("룰렛 삭제", "‘%s’ 룰렛과 결과 기록을 삭제할까요?" % preset.name, func():
  data.presets.erase(preset); preset = data.presets[0]
  _changed(); _refresh_editor(); _refresh_wheel(); _refresh_result())

func _settings() -> void:
 if busy: return
 var dialog := Layer.new(); dialog.theme = theme; dialog.title = "전체 설정"; dialog.show_footer = false; dialog.ok_button_text = "닫기"; dialog.min_size = Vector2i(500,370); add_child(dialog)
 var box := VBoxContainer.new(); box.add_theme_constant_override("separation",12); dialog.add_content(box)
 box.add_child(_label("변경 내용은 자동 저장됩니다.",12))
 box.add_child(_label("회전 시간 · 1–30초"))
 var seconds := SpinBox.new(); seconds.min_value = 1; seconds.max_value = 30; seconds.step = .5; seconds.value = data.settings.duration; seconds.suffix = "초"; box.add_child(seconds)
 seconds.value_changed.connect(func(v): data.settings.duration = v; _changed(); _refresh_wheel())
 var remove := CheckButton.new(); remove.text = "당첨 항목을 다음 회전에서 제외"; remove.button_pressed = data.settings.remove_winner; box.add_child(remove)
 remove.toggled.connect(func(v): data.settings.remove_winner = v; _changed(); _refresh_wheel())
 var sound := CheckButton.new(); sound.text = "회전 · 당첨 효과음"; sound.button_pressed = data.settings.sound; box.add_child(sound)
 sound.toggled.connect(func(v): data.settings.sound = v; _changed())
 _show_settings_layer(dialog)

func _preset_settings() -> void:
 _open_editor()
 await get_tree().process_frame
 await get_tree().process_frame
 if editor_dialog.visible: editor_dialog._scroll.scroll_vertical = int(editor.get_combined_minimum_size().y)

func _editor_preset_settings(box: VBoxContainer) -> void:
 box.add_child(HSeparator.new())
 box.add_child(_label("이 룰렛 설정",22))
 box.add_child(_label("회전 시간",16))
 var duration_group := ButtonGroup.new()
 var inherit := CheckBox.new(); inherit.text = "전체 설정 사용 · %s초" % _weight_text(float(data.settings.duration)); inherit.button_group = duration_group; inherit.button_pressed = preset.duration_override == null; box.add_child(inherit)
 var custom_row := _row(); box.add_child(custom_row)
 var custom := CheckBox.new(); custom.text = "직접 설정"; custom.button_group = duration_group; custom.button_pressed = preset.duration_override != null; custom.size_flags_horizontal = Control.SIZE_EXPAND_FILL; custom_row.add_child(custom)
 for radio in [inherit,custom]:
  radio.custom_minimum_size.y = 44
  _accent_button(radio,true) if radio.button_pressed else _clear_accent(radio)
  radio.toggled.connect(func(on): _accent_button(radio,true) if on else _clear_accent(radio))
  radio.add_theme_icon_override("radio_checked",load("res://assets/radio-on.svg")); radio.add_theme_icon_override("radio_unchecked",load("res://assets/radio-off.svg"))
 var seconds := SpinBox.new(); seconds.min_value = 1; seconds.max_value = 30; seconds.step = .5; seconds.value = _duration(); seconds.suffix = "초"; seconds.editable = custom.button_pressed; seconds.custom_minimum_size.x = 120; custom_row.add_child(seconds)
 inherit.pressed.connect(func(): preset.duration_override = null; seconds.editable = false; seconds.set_value_no_signal(float(data.settings.duration)); _changed(); _refresh_wheel())
 custom.pressed.connect(func(): preset.duration_override = seconds.value; seconds.editable = true; _changed(); _refresh_wheel())
 seconds.value_changed.connect(func(v): if custom.button_pressed: preset.duration_override = v; _changed(); _refresh_wheel())
 box.add_child(_label("당첨 항목 처리",16))
 var remove_row := _row(); box.add_child(remove_row)
 var remove_group := ButtonGroup.new()
 for i in range(3):
  var option := Button.new(); option.text = ["전체 설정 사용","유지","제외"][i]; option.toggle_mode = true; option.button_group = remove_group; option.size_flags_horizontal = Control.SIZE_EXPAND_FILL; option.custom_minimum_size.y = 44
  option.button_pressed = (preset.remove_override == null and i == 0) or (preset.remove_override != null and i == (2 if preset.remove_override else 1)); remove_row.add_child(option)
  if option.button_pressed: _accent_button(option,true)
  option.pressed.connect(func():
   preset.remove_override = null if i == 0 else i == 2; _changed(); _refresh_wheel()
   for item in remove_row.get_children():
    for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]: item.remove_theme_stylebox_override(state)
    for color_key in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_disabled_color"]: item.remove_theme_color_override(color_key)
    if item.button_pressed: _accent_button(item,true))
 var hint := _label("전체 설정을 따르는 항목만 기본값과 함께 바뀝니다.",12); hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(hint)

func _history(page: int = 0) -> void:
 if busy: return
 history_dialog = Layer.new(); history_dialog.theme = theme; history_dialog.exclusive = true; history_dialog.title = "결과 기록"; history_dialog.show_footer = false; history_dialog.min_size = Vector2i(500,370); add_child(history_dialog)
 var box := VBoxContainer.new(); box.add_theme_constant_override("separation",18); history_dialog.add_content(box)
 var subtitle := _label(preset.name,16); subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; subtitle.add_theme_color_override("font_color",Color("737d78")); box.add_child(subtitle)
 var list := VBoxContainer.new(); list.add_theme_constant_override("separation",14); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_child(list)
 if preset.history.is_empty(): list.add_child(_label("아직 기록이 없습니다.",16))
 page = clampi(page,0,maxi(0,(preset.history.size()-1)/100))
 var start: int = preset.history.size() - 1 - page * 100
 var end := maxi(-1, start - 100)
 for i in range(start, end, -1):
  var h: Dictionary = preset.history[i]
  var row := _row(); row.add_theme_constant_override("separation",14); list.add_child(row)
  if h.has("color") and Color.html_is_valid(str(h.color)):
   var dot := Panel.new(); dot.custom_minimum_size = Vector2(12,12); dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
   var swatch := StyleBoxFlat.new(); swatch.bg_color = Color(h.color); swatch.set_corner_radius_all(6); dot.add_theme_stylebox_override("panel",swatch); row.add_child(dot)
  var detail := VBoxContainer.new(); detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL; detail.add_theme_constant_override("separation",5); row.add_child(detail)
  var winner_label := _label(str(h.name),22); winner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; detail.add_child(winner_label)
  if not str(h.get("at", "")).is_empty():
   var timestamp := _label(str(h.at),13); timestamp.add_theme_color_override("font_color",Color("737d78")); detail.add_child(timestamp)
  if i > end + 1: list.add_child(HSeparator.new())
 var paging := _row(); box.add_child(paging)
 if page > 0: paging.add_child(_button("최근 기록", func(): history_dialog.queue_free(); _history(page - 1)))
 if end >= 0: paging.add_child(_button("이전 기록", func(): history_dialog.queue_free(); _history(page + 1)))
 var footer := _row(); box.add_child(footer)
 var count := _label("%d개 기록" % preset.history.size(),14); count.size_flags_horizontal = Control.SIZE_EXPAND_FILL; footer.add_child(count)
 var reset := _button("기록 초기화", func():
  _confirm("기록 초기화", "이 룰렛의 당첨 기록을 모두 지울까요? 되돌릴 수 없습니다.", func(): preset.history.clear(); _save(); _refresh_result(); history_dialog.queue_free()))
 _danger_button(reset); reset.disabled = preset.history.is_empty(); footer.add_child(reset)
 history_dialog.confirmed.connect(history_dialog.queue_free); history_dialog.canceled.connect(history_dialog.queue_free); history_dialog.popup_centered()

func _confirm(title_text: String, message: String, action: Callable) -> void:
 var d := Layer.new(); d.transparent_bg = true; d.theme = theme; d.exclusive = true; d.title = title_text; d.dialog_text = message; d.ok_button_text = "확인"; d.cancel_button_text = "취소"; _layer_parent().add_child(d)
 d.set_confirmation(); d.confirmed.connect(func(): action.call_deferred(); d.queue_free()); d.canceled.connect(d.queue_free); d.popup_centered()

func _message(title_text: String, message: String) -> void:
 var d := Layer.new(); d.transparent_bg = true; d.theme = theme; d.exclusive = true; d.title = title_text; d.dialog_text = message; _layer_parent().add_child(d); d.confirmed.connect(d.queue_free); d.canceled.connect(d.queue_free); d.popup_centered()

func _sound(victory: bool) -> void:
 if not data.settings.sound: return
 audio.stream = load("res://assets/victory.wav" if victory else "res://assets/spin.wav")
 audio.play()

func _commit_inputs(node: Node) -> void:
 for child in node.get_children():
  if child is SpinBox: child.apply()
  _commit_inputs(child)

func _has_layer() -> bool:
 return _top_layer() != null

func _top_layer() -> Control:
 var layers := get_tree().get_nodes_in_group("wheel_layers")
 for i in range(layers.size() - 1, -1, -1):
  if is_instance_valid(layers[i]) and layers[i].is_visible_in_tree(): return layers[i]
 return null

func _layer_parent() -> Node:
 return self

func _close_top_layer(_node: Node = self) -> bool:
 var layer := _top_layer()
 if layer == null: return false
 if _cancel_reorder(layer): return true
 layer.request_close()
 return true

func _show_settings_layer(dialog: Control) -> void:
 var close := func():
  _commit_inputs(dialog)
  _save()
  dialog.queue_free()
 dialog.confirmed.connect(close); dialog.canceled.connect(close)
 dialog.popup_centered()

func _register_layer(_node: Node) -> void:
 pass

func _sync_scrim() -> void:
 pass

func _pick_color(slice: Dictionary) -> void:
 var dialog := Layer.new(); dialog.title = "칸 색상"; add_child(dialog)
 var picker := ColorPicker.new(); picker.color = Color(slice.color); picker.edit_alpha = false
 picker.presets_visible = false; picker.sampler_visible = false; picker.color_modes_visible = false
 dialog.add_content(picker)
 picker.color_changed.connect(func(value): slice.color = "#" + value.to_html(false); _definition_changed())
 var close := func(): _save(); dialog.queue_free(); _refresh_editor.call_deferred()
 dialog.confirmed.connect(close); dialog.canceled.connect(close); dialog.popup_centered(Vector2i(460, 560))

func _settings_hub() -> void:
 _settings()

func _switch_layer(dialog: Control, action: Callable) -> void:
 dialog.hide(); dialog.queue_free(); action.call_deferred()

func _animate_spin(t: float) -> void:
 # Quintic trajectory matches release velocity and ends with zero velocity/acceleration.
 var v := spin_initial_velocity * spin_seconds
 var t2 := t * t
 var t3 := t2 * t
 wheel.rotation = spin_start + v * t + (10 * spin_distance - 6 * v) * t3 + (-15 * spin_distance + 8 * v) * t3 * t + (6 * spin_distance - 3 * v) * t3 * t2

func _wheel_position(viewport_position: Vector2) -> Vector2:
 var holder := wheel.get_parent() as Control
 return holder.get_global_transform_with_canvas().affine_inverse() * viewport_position - holder.size / 2

func _input(event: InputEvent) -> void:
 if wheel == null: return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
  if _close_top_layer(): get_viewport().set_input_as_handled()
  return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
  if not busy and not _has_layer(): _spin(); get_viewport().set_input_as_handled()
  return
 if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION: return
 if event is InputEventScreenTouch:
  if event.pressed: _begin_drag(event.position, event.index)
  elif dragging and drag_pointer == event.index:
   if event.canceled: _cancel_drag()
   else: _end_drag()
 elif event is InputEventScreenDrag:
  if dragging and drag_pointer == event.index: _move_drag(event.position)
 elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
  if event.pressed: _begin_drag(event.position, -1)
  elif dragging and drag_pointer == -1: _end_drag()
 elif event is InputEventMouseMotion and dragging and drag_pointer == -1:
  _move_drag(event.position)

func _begin_drag(position_value: Vector2, pointer: int) -> void:
 if busy or dragging or _has_layer() or not Model.validate_preset(preset).is_empty() or Model.active_slices(preset).size() < 2: return
 var local := _wheel_position(position_value)
 var radius := minf(wheel.size.x, wheel.size.y) / 2 - 12
 if local.length() > radius or local.length() < radius * .22: return
 dragging = true; busy = true; drag_pointer = pointer
 drag_last_angle = local.angle(); drag_last_time = Time.get_ticks_usec() / 1000000.0
 drag_distance = 0; drag_velocity = 0
 wheel.slices = Model.active_slices(preset); wheel.queue_redraw()
 _refresh_editor(); _refresh_wheel()
 OS.low_processor_usage_mode = false
 get_viewport().set_input_as_handled()

func _move_drag(position_value: Vector2) -> void:
 var local := _wheel_position(position_value)
 if local.length() < minf(wheel.size.x, wheel.size.y) * .11: return
 var now := Time.get_ticks_usec() / 1000000.0
 var dt := maxf(.001, now - drag_last_time)
 var delta_angle := wrapf(local.angle() - drag_last_angle, -PI, PI)
 wheel.rotation += delta_angle
 drag_distance += absf(delta_angle)
 var sample := clampf(delta_angle / dt, -40, 40)
 drag_velocity = sample if drag_distance < .2 else lerpf(drag_velocity, sample, .65)
 drag_last_angle = local.angle(); drag_last_time = now
 get_viewport().set_input_as_handled()

func _end_drag() -> void:
 var age := Time.get_ticks_usec() / 1000000.0 - drag_last_time
 var velocity := drag_velocity * exp(-age * 6.0)
 var should_spin := drag_distance >= .16 and absf(velocity) >= .6
 dragging = false; busy = false; drag_pointer = -2
 current_rotation = fposmod(wheel.rotation, TAU)
 _refresh_editor(); _refresh_wheel()
 if should_spin: _spin(signf(velocity), absf(velocity))
 else: OS.low_processor_usage_mode = true
 get_viewport().set_input_as_handled()

func _cancel_drag() -> void:
 if not dragging: return
 dragging = false; busy = false; drag_pointer = -2
 current_rotation = fposmod(wheel.rotation, TAU)
 OS.low_processor_usage_mode = true
 _refresh_editor(); _refresh_wheel()

func _icon_button(path: String, description: String, action: Callable) -> Button:
 var button := _button("", action); button.icon = load(path); button.tooltip_text = description; button.custom_minimum_size = Vector2(56,56)
 for property in button.get_property_list():
  if property.name == "accessibility_name": button.set("accessibility_name",description)
 return button

func _set_integer_weight(slice: Dictionary, value: String, mode: String = "ratio") -> bool:
 if value.length() > (3 if mode == "percent" else 7) or not value.is_valid_int(): return false
 var parsed := value.to_int()
 if parsed <= 0 or parsed > (100 if mode == "percent" else 1000000): return false
 slice.weight = float(parsed)
 return true

func _equalize() -> void:
 if busy: return
 var count: int = preset.slices.size()
 if count < 1: return
 if preset.mode == "percent" and count > 100:
  _message("균등 분배", "양의 정수 백분율은 최대 100개 항목에만 분배할 수 있습니다."); return
 for i in range(count):
  preset.slices[i].weight = 1.0 if preset.mode == "ratio" else float(100 / count + (1 if i < 100 % count else 0))
 _definition_changed(); _refresh_editor()

func _weight_text(value: float) -> String:
 return str(int(value)) if value == floorf(value) else str(value)

func _accent_button(button: Button, soft := false) -> void:
 var normal := StyleBoxFlat.new(); normal.bg_color = Color("e7f5f7") if soft else Color("087c8c"); normal.set_corner_radius_all(12); normal.set_content_margin_all(12)
 normal.border_color = Color("82bec6"); normal.set_border_width_all(1 if soft else 0)
 button.add_theme_stylebox_override("normal",normal)
 var hover := normal.duplicate() as StyleBoxFlat; hover.bg_color = Color("d9eef1") if soft else Color("066979")
 button.add_theme_stylebox_override("hover",hover); button.add_theme_stylebox_override("pressed",hover); button.add_theme_stylebox_override("hover_pressed",hover)
 var disabled_style := normal.duplicate() as StyleBoxFlat; disabled_style.bg_color = Color("e6eeeb"); button.add_theme_stylebox_override("disabled",disabled_style)
 var focus := StyleBoxFlat.new(); focus.bg_color = Color(0,0,0,0); focus.border_color = Color("82bec6"); focus.set_border_width_all(2); focus.set_corner_radius_all(12); button.add_theme_stylebox_override("focus",focus)
 for key in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_disabled_color"]: button.add_theme_color_override(key,Color("066979") if soft else Color.WHITE)
 button.add_theme_color_override("font_disabled_color",Color("526d68"))

func _clear_accent(button: Button) -> void:
 for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]: button.remove_theme_stylebox_override(state)
 for key in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_disabled_color"]: button.remove_theme_color_override(key)

func _danger_button(button: Button) -> void:
 var style := StyleBoxFlat.new(); style.bg_color = Color("fff1f3"); style.border_color = Color("e7a5ae"); style.set_border_width_all(1); style.set_corner_radius_all(12); style.set_content_margin_all(8)
 for state in ["normal","hover","pressed","hover_pressed","disabled"]:
  var variant := style.duplicate() as StyleBoxFlat
  if state in ["hover","pressed","hover_pressed"]: variant.bg_color = Color("ffe3e7")
  button.add_theme_stylebox_override(state,variant)
 var focus := style.duplicate() as StyleBoxFlat; focus.bg_color = Color.TRANSPARENT; focus.set_border_width_all(2); button.add_theme_stylebox_override("focus",focus)
 for key in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_disabled_color"]: button.add_theme_color_override(key,Color("b83243"))

func _reorder_slices(from_index: int, to_index: int) -> void:
 if busy or from_index == to_index: return
 if Model.move_entry(preset.slices, from_index, to_index):
  current_rotation = 0; wheel.rotation = 0; _refresh_wheel(); _refresh_editor(); _save(); _restore_reorder_focus.call_deferred(editor,to_index)

func _reorder_presets(from_index: int, to_index: int) -> void:
 if busy or from_index == to_index: return
 if Model.move_entry(data.presets, from_index, to_index):
  _save(); _refresh_manager(); _refresh_picker()
  if is_instance_valid(manager_dialog): _restore_reorder_focus.call_deferred(manager_dialog.content,to_index)

func _preset_manager() -> void:
 if busy: return
 if is_instance_valid(manager_dialog): manager_dialog.queue_free()
 manager_dialog = Layer.new(); manager_dialog.title = "프리셋 관리"; manager_dialog.show_footer = false; add_child(manager_dialog)
 manager_dialog.canceled.connect(manager_dialog.queue_free)
 _refresh_manager(); manager_dialog.popup_centered(Vector2i(620,680))

func _refresh_manager() -> void:
 if not is_instance_valid(manager_dialog): return
 for child in manager_dialog.content.get_children(): child.hide(); child.queue_free()
 var list := VBoxContainer.new(); list.add_theme_constant_override("separation",14); manager_dialog.add_content(list)
 var top := HBoxContainer.new(); top.alignment = BoxContainer.ALIGNMENT_END; list.add_child(top)
 var add := _button("추가", _add_preset_dialog); _accent_button(add); add.disabled = data.presets.size() >= Model.MAX_PRESETS; top.add_child(add)
 for i in range(data.presets.size()):
  var p: Dictionary = data.presets[i]
  var card := PanelContainer.new(); card.set_meta("row_index",i); list.add_child(card)
  var style := StyleBoxFlat.new(); style.bg_color = Color("e7f5f7") if p.id == preset.id else Color("f7f8f5"); style.border_color = Color("82bec6") if p.id == preset.id else Color("d9ddd6"); style.set_border_width_all(1); style.set_corner_radius_all(16); style.set_content_margin_all(12); card.add_theme_stylebox_override("panel",style)
  var row := _row(); row.add_theme_constant_override("separation",8); card.add_child(row)
  var handle := Reorder.new(); handle.caption = str(p.name); row.add_child(handle); handle.configure(list,card,i,manager_dialog._scroll); handle.reordered.connect(_reorder_presets)
  var preview := Wheel.new(); preview.show_labels = false; preview.slices = p.slices; preview.custom_minimum_size = Vector2(72,90); row.add_child(preview)
  var details := VBoxContainer.new(); details.size_flags_horizontal = Control.SIZE_EXPAND_FILL; details.add_theme_constant_override("separation",12); row.add_child(details)
  var heading := _row(); details.add_child(heading)
  var name_label := _label(p.name,18); name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; heading.add_child(name_label)
  var star := _button("", func(): _toggle_favorite(p.id)); star.icon = load("res://assets/star-on.svg" if p.get("favorite",false) else "res://assets/star-off.svg"); star.custom_minimum_size = Vector2(40,40); star.tooltip_text = "즐겨찾기 해제" if p.get("favorite",false) else "즐겨찾기 추가"; heading.add_child(star); star.accessibility_name = star.tooltip_text + " · " + str(p.name)
  var actions := _row(); actions.add_theme_constant_override("separation",6); details.add_child(actions)
  var choose := _button("선택됨" if p.id == preset.id else "선택", func(): _manager_select(p.id)); choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  if p.id == preset.id: _accent_button(choose)
  actions.add_child(choose)
  var edit := _button("룰렛 편집", func(): _manager_edit(p.id)); edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; actions.add_child(edit)
  var remove := _button("삭제",func(): _manager_delete(p.id)); _danger_button(remove); remove.disabled = data.presets.size() <= 1; actions.add_child(remove)

func _find_preset(id: String) -> Dictionary:
 for p in data.presets:
  if p.id == id: return p
 return {}

func _toggle_favorite(id: String) -> void:
 if busy: return
 var p := _find_preset(id)
 if p.is_empty(): return
 p.favorite = not p.get("favorite",false)
 _save(); _refresh_manager()

func _manager_select(id: String) -> void:
 if busy: return
 var p := _find_preset(id)
 if p.is_empty(): return
 _select_preset(data.presets.find(p)); _refresh_manager()

func _manager_edit(id: String) -> void:
 if busy: return
 _manager_select(id)
 if is_instance_valid(manager_dialog): manager_dialog.hide(); manager_dialog.queue_free()
 _open_editor()

func _manager_delete(id: String) -> void:
 if busy or data.presets.size() <= 1: return
 var p := _find_preset(id)
 if p.is_empty(): return
 _confirm("프리셋 삭제", "‘%s’ 프리셋과 결과 기록을 삭제할까요?" % p.name,func():
  data.presets.erase(p)
  if preset.id == id: preset = data.presets[0]; current_rotation = 0; wheel.rotation = 0
  _save(); _refresh_picker(); _refresh_editor(); _refresh_result(); _refresh_wheel(); _refresh_manager())

func _add_preset_dialog() -> void:
 if busy or data.presets.size() >= Model.MAX_PRESETS: return
 var dialog := Layer.new(); dialog.title = "프리셋 추가"; dialog.ok_button_text = "추가"; dialog.set_confirmation(); add_child(dialog)
 var name := LineEdit.new(); name.placeholder_text = "새 프리셋 이름"; name.max_length = 40; name.custom_minimum_size.y = 46; dialog.add_content(name)
 dialog.get_ok_button().disabled = true
 name.text_changed.connect(func(value): dialog.get_ok_button().disabled = value.strip_edges().is_empty())
 dialog.confirmed.connect(func():
  if not name.text.strip_edges().is_empty():
   _new_preset(); preset.name = name.text.strip_edges(); _save(); _refresh_picker(); _refresh_editor(); _refresh_manager()
  dialog.queue_free())
 dialog.canceled.connect(dialog.queue_free); dialog.popup_centered(Vector2i(420,240))

func _restore_reorder_focus(node: Node, target_index: int) -> void:
 if not is_instance_valid(node) or not node.is_inside_tree(): return
 if node is Reorder and node.index == target_index and node.is_visible_in_tree():
  node.grab_focus(); return
 for child in node.get_children(): _restore_reorder_focus(child,target_index)

func _cancel_reorder(node: Node) -> bool:
 if node is Reorder and node._pressed:
  node._cancel(); return true
 for child in node.get_children():
  if _cancel_reorder(child): return true
 return false
