extends Control

const Model = preload("res://scripts/wheel_model.gd")
const Wheel = preload("res://scripts/wheel_canvas.gd")
const PALETTE = ["#a89bea", "#ffcc75", "#7ad3b9", "#f69ca9", "#83b9ed", "#d8b1df", "#a8d584", "#f4b18c"]
var data: Dictionary
var preset: Dictionary
var busy := false
var wheel: Control
var body: GridContainer
var editor: VBoxContainer
var selectors: OptionButton
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
var history_dialog: AcceptDialog
var narrow := false
var editor_dialog: AcceptDialog
var main_selector: OptionButton
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
  if "--editor-shot" in OS.get_cmdline_user_args(): _open_editor()
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
 t.set_color("font_color", "Label", Color("263352"))
 for cls in ["Button", "OptionButton", "LineEdit", "SpinBox", "CheckButton", "CheckBox"]:
  t.set_color("font_color", cls, Color("263352"))
  t.set_color("font_hover_color", cls, Color("5340ae"))
  t.set_color("font_focus_color", cls, Color("263352"))
  t.set_color("font_pressed_color", cls, Color("263352"))
  t.set_color("font_disabled_color", cls, Color("9a98a9"))
 for state in ["normal", "hover", "pressed", "focus", "disabled"]:
  var s := StyleBoxFlat.new()
  s.bg_color = Color(1,1,1,.88) if state == "normal" else Color("e8e0ff")
  if state == "disabled": s.bg_color = Color("e8eaf0")
  s.set_corner_radius_all(22)
  s.content_margin_left = 16; s.content_margin_right = 16
  s.content_margin_top = 11; s.content_margin_bottom = 11
  s.border_color = Color("dedfed")
  s.set_border_width_all(0)
  t.set_stylebox(state, "Button", s)
  t.set_stylebox(state, "OptionButton", s)
  t.set_stylebox(state, "LineEdit", s)
 var panel := StyleBoxFlat.new()
 panel.bg_color = Color.WHITE
 panel.set_corner_radius_all(28)
 panel.content_margin_left = 24; panel.content_margin_right = 24
 panel.content_margin_top = 24; panel.content_margin_bottom = 24
 t.set_stylebox("panel", "PanelContainer", panel)
 t.set_stylebox("panel", "AcceptDialog", panel)
 var border := StyleBoxFlat.new(); border.bg_color = Color.WHITE; border.border_color = Color("eae6f9"); border.set_border_width_all(2); border.border_width_top = 36; border.expand_margin_top = 36; border.expand_margin_left = 2; border.expand_margin_right = 2; border.expand_margin_bottom = 2; border.set_corner_radius_all(16)
 t.set_stylebox("embedded_border", "Window", border)
 t.set_constant("title_height", "Window", 36); t.set_font_size("title_font_size", "Window", 16)
 t.set_color("title_color", "Window", Color("3d3457"))
 t.set_icon("close", "Window", load("res://assets/close.svg")); t.set_icon("close_pressed", "Window", load("res://assets/close.svg"))
 theme = t

func _label(text: String, fs := 16) -> Label:
 var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", fs)
 return l

func _button(text: String, action: Callable) -> Button:
 var b := Button.new(); b.text = text; b.pressed.connect(action); b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
 main_selector = OptionButton.new(); main_selector.fit_to_longest_item = false; main_selector.clip_text = true; main_selector.custom_minimum_size.x = 220; main_selector.tooltip_text = "프리셋 전환"; center.add_child(main_selector)
 main_selector.item_selected.connect(_select_preset)
 var gear := _button("", _settings_hub); gear.icon = load("res://assets/settings.svg"); gear.custom_minimum_size = Vector2(48,48); gear.tooltip_text = "설정"; header.add_child(gear)
 for property in gear.get_property_list():
  if property.name == "accessibility_name": gear.set("accessibility_name", "설정")
 var last := PanelContainer.new(); last.size_flags_horizontal = Control.SIZE_SHRINK_END; var result_style := theme.get_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat; result_style.content_margin_top = 14; result_style.content_margin_bottom = 14; last.add_theme_stylebox_override("panel", result_style); outer.add_child(last)
 var lr := _row(); last.add_child(lr)
 result = _label("첫 번째 행운을 돌려보세요", 20)
 result.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
 spin_button = _button("▶", _spin); spin_button.tooltip_text = "돌리기 (Space)"; spin_button.custom_minimum_size = Vector2(56,48); spin_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; spin_button.add_theme_font_size_override("font_size", 21)
 spin_button.modulate = Color("d9ded8"); spin_button.custom_minimum_size = Vector2(64,56)
 status = _label("", 14); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; stage_box.add_child(status)
 duration_label = _label("", 13); duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; stage_box.add_child(duration_label); duration_label.hide()
 var controls := _row(); controls.alignment = BoxContainer.ALIGNMENT_CENTER; stage_box.add_child(controls)
 controls.add_child(_icon_button("res://assets/restart.svg", "라운드 복원", _reset_round))
 controls.add_child(spin_button)
 controls.add_child(_icon_button("res://assets/history.svg", "결과 기록", _history))
 scrim = ColorRect.new(); scrim.color = Color(0.10,0.12,0.20,0.38); scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); scrim.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(scrim); scrim.hide()
 editor_dialog = AcceptDialog.new(); editor_dialog.theme = theme; editor_dialog.title = "칸 편집 · 프리셋 관리"; editor_dialog.ok_button_text = "닫기"; editor_dialog.exclusive = true; add_child(editor_dialog)
 editor_dialog.confirmed.connect(_close_editor); editor_dialog.canceled.connect(_close_editor)
 var edit_scroll := ScrollContainer.new(); edit_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; edit_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; edit_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; editor_dialog.add_child(edit_scroll)
 editor = VBoxContainer.new(); editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL; editor.add_theme_constant_override("separation", 13); edit_scroll.add_child(editor)
 _refresh_editor(); _refresh_wheel(); _refresh_result()
 editor_dialog.hide()

func _responsive() -> void:
 if body == null: return
 main_selector.custom_minimum_size.x = clampf(size.x - 180, 180, 440)
 narrow = size.x < 880
 body.columns = 1
 wheel_aspect.custom_minimum_size.y = 400 if narrow else 430
 stage_spacer.custom_minimum_size.y = maxf(8, (size.y - wheel_aspect.custom_minimum_size.y - 160) / 2)
 if editor_dialog.visible: _size_editor()

func _size_editor() -> void:
 var available := get_viewport_rect().size
 var target := Vector2i(mini(560, int(available.x) - 32), mini(620, int(available.y) - 48))
 var scroll := editor_dialog.get_child(0) as ScrollContainer
 # The content scrolls; a long preset never increases the overlay beyond screen.
 if scroll == null:
  for child in editor_dialog.get_children():
   if child is ScrollContainer: scroll = child; break
 if scroll != null: scroll.custom_minimum_size = Vector2(target.x - 24, target.y - 90)
 editor_dialog.size = target
 editor_dialog.position = Vector2i((available - Vector2(target)) / 2)

func _open_editor() -> void:
 if busy: return
 editor_opener = get_viewport().gui_get_focus_owner()
 _refresh_editor()
 _size_editor()
 editor_dialog.popup_centered(editor_dialog.size)

func _close_editor() -> void:
 _commit_inputs(editor)
 editor_dialog.hide()
 if is_instance_valid(editor_opener): editor_opener.grab_focus()
 _save()
 _refresh_wheel()

func _select_preset(i: int) -> void:
 if busy: return
 preset = data.presets[i]; current_rotation = 0; wheel.rotation = 0
 _refresh_editor(); _refresh_wheel(); _refresh_result()

func _refresh_picker() -> void:
 main_selector.clear()
 for p in data.presets: main_selector.add_item(p.name)
 main_selector.select(data.presets.find(preset))
 main_selector.disabled = busy

func _refresh_result() -> void:
 result.text = str(preset.history.back().name) if not preset.history.is_empty() else "—"
 result.get_parent().get_parent().visible = not preset.history.is_empty()

func _refresh_editor() -> void:
 _refresh_picker()
 for child in editor.get_children(): child.queue_free(); editor.remove_child(child)
 editor.add_child(_label("나의 룰렛", 22))
 var pr := _row(); editor.add_child(pr)
 selectors = OptionButton.new(); selectors.fit_to_longest_item = false; selectors.clip_text = true; selectors.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 for p in data.presets: selectors.add_item(p.name)
 selectors.select(data.presets.find(preset)); selectors.disabled = busy
 selectors.item_selected.connect(_select_preset)
 pr.add_child(selectors)
 var new_button := _button("+ 새로", _new_preset); new_button.disabled = busy or data.presets.size() >= Model.MAX_PRESETS; pr.add_child(new_button)
 var name_input := LineEdit.new(); name_input.text = preset.name; name_input.placeholder_text = "룰렛 이름"; name_input.max_length = 40; name_input.editable = not busy
 name_input.text_changed.connect(func(value): preset.name = value; preset_name.text = value; selectors.set_item_text(data.presets.find(preset),value); _refresh_picker(); _changed())
 editor.add_child(name_input)
 var mode := OptionButton.new(); mode.add_item("비율로 정하기 · 1 : 1"); mode.add_item("백분율로 정하기 · 50 : 50"); mode.select(0 if preset.mode == "ratio" else 1); mode.disabled = busy
 mode.item_selected.connect(_change_mode); editor.add_child(mode)
 var note := _label("이름 · 색상 · 가중치", 13); note.add_theme_color_override("font_color", Color("7f879d")); editor.add_child(note)
 for i in range(preset.slices.size()): _slice_row(i)
 var plus := _button("+ 항목 추가", _add_slice); plus.disabled = busy or preset.slices.size() >= 40; editor.add_child(plus)
 var info := _label("편집 내용은 자동 저장됩니다.\n항목을 편집하면 현재 라운드가 복원됩니다.", 12); info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info.add_theme_color_override("font_color", Color("81899b")); editor.add_child(info)
 var footer := _row(); editor.add_child(footer)
 footer.add_child(_button("이 룰렛 설정", _preset_settings))
 var del := _button("삭제", _delete_preset); del.disabled = busy or data.presets.size() <= 1; footer.add_child(del)
 _lock_buttons(editor, busy)

func _slice_row(index: int) -> void:
 var s: Dictionary = preset.slices[index]
 var r := _row(); editor.add_child(r)
 var color := ColorPickerButton.new(); color.color = Color(s.color); color.custom_minimum_size = Vector2(42,44); color.edit_alpha = false; color.disabled = busy; r.add_child(color)
 color.color_changed.connect(func(c): s.color = "#" + c.to_html(false); _definition_changed())
 var name_edit := LineEdit.new(); name_edit.text = s.name; name_edit.max_length = 40; name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; name_edit.custom_minimum_size.x = 70; name_edit.editable = not busy; r.add_child(name_edit)
 name_edit.text_changed.connect(func(value): s.name = value; _definition_changed())
 var weight := SpinBox.new(); weight.min_value = .01; weight.max_value = 100 if preset.mode == "percent" else 1000000; weight.step = .01; weight.value = s.weight; weight.custom_minimum_size.x = 98; weight.editable = not busy; weight.suffix = "%" if preset.mode == "percent" else ""; r.add_child(weight)
 weight.value_changed.connect(func(value): s.weight = value; _definition_changed())
 var remove := _button("×", func():
  preset.slices.remove_at(index); _definition_changed(); _refresh_editor())
 remove.custom_minimum_size.x = 42; remove.disabled = busy or preset.slices.size() <= 2; r.add_child(remove)

func _lock_buttons(node: Node, locked: bool) -> void:
 if not locked: return
 for child in node.get_children():
  if child is BaseButton: child.disabled = true
  if child is LineEdit: child.editable = false
  _lock_buttons(child, locked)

func _change_mode(index: int) -> void:
 if busy: return
 if index == 1 and preset.mode != "percent":
  var total := 0.0
  for s in preset.slices: total += float(s.weight)
  var assigned := 0.0
  for i in range(preset.slices.size()):
   var value := snappedf(float(preset.slices[i].weight) / total * 100, .01)
   if i == preset.slices.size()-1: value = snappedf(100 - assigned,.01)
   if value <= 0:
    _message("변환할 수 없어요", "너무 작은 비율은 0.01%로 표현할 수 없습니다. 비율 모드를 유지해 주세요."); _refresh_editor(); return
   assigned += value
  # Keep exact weights to preserve probabilities; display editor rounds only.
  for s in preset.slices: s.weight = float(s.weight) / total * 100
 preset.mode = "percent" if index == 1 else "ratio"
 _definition_changed(); _refresh_editor()

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
 var dialog := AcceptDialog.new(); dialog.theme = theme; dialog.title = "전체 설정"; dialog.ok_button_text = "닫기"; dialog.min_size = Vector2i(320,270); add_child(dialog)
 var box := VBoxContainer.new(); box.add_theme_constant_override("separation",12); dialog.add_child(box)
 box.add_child(_label("모든 룰렛의 기본 설정",20))
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
 if busy: return
 if editor_dialog.visible: _close_editor()
 var dialog := AcceptDialog.new(); dialog.theme = theme; dialog.title = "이 룰렛 설정"; dialog.ok_button_text = "닫기"; dialog.min_size = Vector2i(320,260); add_child(dialog)
 var box := VBoxContainer.new(); box.add_theme_constant_override("separation",12); dialog.add_child(box)
 box.add_child(_label("변경 내용은 자동 저장됩니다.",12))
 var custom := CheckButton.new(); custom.text = "회전 시간 직접 설정"; custom.button_pressed = preset.duration_override != null; box.add_child(custom)
 var seconds := SpinBox.new(); seconds.min_value = 1; seconds.max_value = 30; seconds.step = .5; seconds.value = _duration(); seconds.suffix = "초"; seconds.editable = custom.button_pressed; box.add_child(seconds)
 custom.toggled.connect(func(v): preset.duration_override = seconds.value if v else null; seconds.editable = v; _changed(); _refresh_wheel())
 seconds.value_changed.connect(func(v): if custom.button_pressed: preset.duration_override = v; _changed(); _refresh_wheel())
 box.add_child(_label("당첨 항목 처리"))
 var remove := OptionButton.new(); remove.add_item("전체 설정 따르기"); remove.add_item("항상 유지"); remove.add_item("항상 제외"); remove.select(0 if preset.remove_override == null else (2 if preset.remove_override else 1)); box.add_child(remove)
 remove.item_selected.connect(func(i): preset.remove_override = null if i == 0 else i == 2; _changed(); _refresh_wheel())
 _show_settings_layer(dialog)

func _history(page: int = 0) -> void:
 if busy: return
 history_dialog = AcceptDialog.new(); history_dialog.theme = theme; history_dialog.exclusive = true; history_dialog.title = preset.name + " · 결과 기록"; history_dialog.min_size = Vector2i(320,350); add_child(history_dialog)
 var box := VBoxContainer.new(); history_dialog.add_child(box)
 box.add_child(_label("총 %d회 · 최근 결과부터" % preset.history.size(),18))
 var scroll := ScrollContainer.new(); scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; scroll.custom_minimum_size = Vector2(300,260); box.add_child(scroll)
 var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(list)
 if preset.history.is_empty(): list.add_child(_label("아직 결과가 없어요. 한 번 돌려볼까요?",13))
 var start: int = preset.history.size() - 1 - page * 100
 var end := maxi(-1, start - 100)
 for i in range(start, end, -1):
  var h: Dictionary = preset.history[i]
  var l := _label("%d. %s\n%s" % [i+1,h.name,h.at],14); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; list.add_child(l)
 var paging := _row(); box.add_child(paging)
 if page > 0: paging.add_child(_button("최근 기록", func(): history_dialog.queue_free(); _history(page - 1)))
 if end >= 0: paging.add_child(_button("이전 기록", func(): history_dialog.queue_free(); _history(page + 1)))
 var reset := _button("이 룰렛의 기록 초기화", func():
  _confirm("기록 초기화", "이 룰렛의 당첨 기록을 모두 지울까요? 되돌릴 수 없습니다.", func(): preset.history.clear(); _save(); _refresh_result(); history_dialog.queue_free()))
 reset.disabled = preset.history.is_empty(); box.add_child(reset)
 history_dialog.confirmed.connect(history_dialog.queue_free); history_dialog.canceled.connect(history_dialog.queue_free); history_dialog.popup_centered()

func _confirm(title_text: String, message: String, action: Callable) -> void:
 var d := ConfirmationDialog.new(); d.theme = theme; d.exclusive = true; d.title = title_text; d.dialog_text = message; d.ok_button_text = "확인"; d.cancel_button_text = "취소"; _layer_parent().add_child(d)
 d.confirmed.connect(func(): action.call(); d.queue_free()); d.canceled.connect(d.queue_free); d.popup_centered()

func _message(title_text: String, message: String) -> void:
 var d := AcceptDialog.new(); d.theme = theme; d.exclusive = true; d.title = title_text; d.dialog_text = message; _layer_parent().add_child(d); d.confirmed.connect(d.queue_free); d.canceled.connect(d.queue_free); d.popup_centered()

func _sound(victory: bool) -> void:
 if not data.settings.sound: return
 audio.stream = load("res://assets/victory.wav" if victory else "res://assets/spin.wav")
 audio.play()

func _commit_inputs(node: Node) -> void:
 for child in node.get_children():
  if child is SpinBox: child.apply()
  _commit_inputs(child)

func _has_layer() -> bool:
 for child in get_children():
  if child is Window and child.visible: return true
 return false

func _layer_parent() -> Node:
 for child in get_children():
  if child is Window and child.visible: return child
 return self

func _close_top_layer(node: Node = self) -> bool:
 var children := node.get_children()
 children.reverse()
 for child in children:
  if child is Window and child.visible:
   if _close_top_layer(child): return true
   child.hide()
   if child is AcceptDialog: child.canceled.emit()
   else: child.close_requested.emit()
   return true
 return false

func _show_settings_layer(dialog: AcceptDialog) -> void:
 dialog.exclusive = true
 var opener := get_viewport().gui_get_focus_owner()
 var close := func():
  _commit_inputs(dialog)
  _save()
  dialog.queue_free()
  if is_instance_valid(opener): opener.grab_focus()
 dialog.confirmed.connect(close); dialog.canceled.connect(close)
 dialog.popup_centered()

func _register_layer(node: Node) -> void:
 if node is Window:
  node.visibility_changed.connect(_sync_scrim)
  node.tree_exiting.connect(func(): _sync_scrim.call_deferred())

func _sync_scrim() -> void:
 if is_instance_valid(scrim): scrim.visible = _has_layer()

func _settings_hub() -> void:
 if busy: return
 var dialog := AcceptDialog.new(); dialog.theme = theme; dialog.title = "설정"; dialog.ok_button_text = "닫기"; dialog.min_size = Vector2i(310,260); add_child(dialog)
 var box := VBoxContainer.new(); box.add_theme_constant_override("separation",12); dialog.add_child(box)
 box.add_child(_button("칸 편집 · 프리셋 관리", func(): _switch_layer(dialog, _open_editor)))
 box.add_child(_button("현재 룰렛 설정", func(): _switch_layer(dialog, _preset_settings)))
 box.add_child(_button("전체 설정", func(): _switch_layer(dialog, _settings)))
 _show_settings_layer(dialog)

func _switch_layer(dialog: AcceptDialog, action: Callable) -> void:
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
