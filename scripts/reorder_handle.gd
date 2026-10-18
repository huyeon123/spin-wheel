extends Control
## Handle-only reordering. The parent performs the model mutation after reordered.
## Every draggable row must have integer row_index metadata; other children are ignored.
signal reordered(from_index: int, to_index: int)

const DRAG_THRESHOLD := 8.0
const EDGE_ZONE := 44.0
const SCROLL_SPEED := 460.0

var list_container: VBoxContainer
var row: Control
var index: int = -1
var scroll: ScrollContainer
var caption: String = ""
var swatch_color: Color = Color.TRANSPARENT
var disabled: bool = false:
	set(value):
		disabled = value
		mouse_default_cursor_shape = Control.CURSOR_ARROW if value else Control.CURSOR_DRAG
		if value:
			_cancel()
		queue_redraw()

var _pressed := false
var _dragging := false
var _touch_index := -1
var _press_position := Vector2.ZERO
var _pointer := Vector2.ZERO
var _ghost_grab_offset_y := 0.0
var _target := -1
var _visual_layer: CanvasLayer
var _visual: DragVisual
var _scroll_remainder := 0.0
var _suppress_emulated_mouse := false

class DragVisual extends Control:
	const TEAL := Color("087c8c")
	var ghost := Rect2()
	var line_from := Vector2.ZERO
	var line_to := Vector2.ZERO
	var caption := ""
	var swatch_color := Color.TRANSPARENT
	var caption_font: Font
	func _draw() -> void:
		# The marker belongs to the list, not the floating preview. Paint it behind
		# the opaque ghost so crossing an insertion point never moves the preview.
		draw_line(line_from, line_to, TEAL, 3.0, true)
		draw_circle(line_from, 4.0, TEAL)
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color(0.04, 0.14, 0.16, 0.10)
		shadow.set_corner_radius_all(10)
		draw_style_box(shadow, Rect2(ghost.position + Vector2(0, 3), ghost.size))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.98, 0.99, 0.98, 1.0)
		style.border_color = Color(TEAL, 0.65)
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		draw_style_box(style, ghost)
		var text_x := 12.0
		if swatch_color.a > 0.0:
			draw_circle(ghost.position + Vector2(20, ghost.size.y * 0.5), 7.0, swatch_color)
			text_x = 36.0
		if caption_font != null:
			var baseline := ghost.position.y + (ghost.size.y - caption_font.get_height(14)) * 0.5 + caption_font.get_ascent(14)
			draw_string(caption_font, Vector2(ghost.position.x + text_x, baseline), caption,
				HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, ghost.size.x - text_x - 12), 14, Color("254341"))

func _init() -> void:
	custom_minimum_size = Vector2(32, 44)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = "끌어서 순서 변경 · Alt+↑/↓"
	accessibility_name = "항목 순서 변경"
	accessibility_description = "끌어서 이동하거나 Alt와 위쪽 또는 아래쪽 화살표를 누르세요."

func configure(list: VBoxContainer, item_row: Control, item_index: int, scroll_container: ScrollContainer = null) -> void:
	_cancel()
	list_container = list
	row = item_row
	index = item_index
	scroll = scroll_container
	if is_instance_valid(row):
		row.set_meta("row_index", index)

func _ready() -> void:
	focus_entered.connect(queue_redraw)
	focus_exited.connect(_on_focus_exited)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	set_process(false)
	set_process_input(false)

func _draw() -> void:
	var color := Color(0.43, 0.48, 0.59, 0.4 if disabled else 1.0)
	if has_focus():
		draw_style_box(get_theme_stylebox("focus", "Button"), Rect2(Vector2.ZERO, size))
	for x in [-3.5, 3.5]:
		for y in [-7.0, 0.0, 7.0]:
			draw_circle(size * 0.5 + Vector2(x, y), 1.65, color)

func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.alt_pressed:
		if event.keycode == KEY_UP or event.keycode == KEY_DOWN:
			var destination := index + (-1 if event.keycode == KEY_UP else 1)
			if destination >= 0 and destination < _rows().size():
				_cancel()
				_emit_reorder.call_deferred(index, destination)
			accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed and not _pressed:
			_suppress_emulated_mouse = true
			_begin(get_global_transform_with_canvas() * event.position, event.index)
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION and _suppress_emulated_mouse:
			accept_event()
			return
		if event.pressed and not _pressed:
			_suppress_emulated_mouse = false
			_begin(get_global_transform_with_canvas() * event.position, -1)
			accept_event()

func _begin(position_in_viewport: Vector2, touch: int) -> void:
	if not is_instance_valid(list_container) or not is_instance_valid(row) or index < 0:
		return
	grab_focus()
	_pressed = true
	_dragging = false
	_touch_index = touch
	_press_position = position_in_viewport
	_pointer = position_in_viewport
	var source_rect := _viewport_rect(row)
	var ghost_height := minf(source_rect.size.y, 48.0)
	var initial_ghost_y := source_rect.position.y + (source_rect.size.y - ghost_height) * 0.5
	_ghost_grab_offset_y = clampf(position_in_viewport.y - initial_ghost_y, 0.0, ghost_height)
	_target = index
	_scroll_remainder = 0.0
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if not _pressed:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == _touch_index:
		if event.canceled:
			_cancel()
		elif not event.pressed:
			_pointer = event.position
			_finish()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_move(event.position)
		get_viewport().set_input_as_handled()
	elif _touch_index == -1 and event is InputEventMouseMotion:
		_move(event.position)
		get_viewport().set_input_as_handled()
	elif _touch_index == -1 and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_pointer = event.position
		_finish()
		get_viewport().set_input_as_handled()

func _move(position_in_viewport: Vector2) -> void:
	_pointer = position_in_viewport
	if not _dragging and _pointer.distance_to(_press_position) >= DRAG_THRESHOLD:
		_dragging = true
		_visual_layer = CanvasLayer.new()
		_visual_layer.layer = 100
		add_child(_visual_layer)
		_visual = DragVisual.new()
		_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_visual.caption_font = get_theme_default_font()
		_visual.swatch_color = swatch_color
		_visual_layer.add_child(_visual)
		set_process(true)
	if _dragging:
		_update_target()

func _rows() -> Array[Control]:
	var result: Array[Control] = []
	if not is_instance_valid(list_container):
		return result
	for child in list_container.get_children():
		if child is Control and child.has_meta("row_index") and child.is_visible_in_tree():
			result.append(child)
	return result

func _viewport_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _update_target() -> void:
	if not is_instance_valid(row) or not is_instance_valid(_visual):
		_cancel()
		return
	var rows := _rows()
	if rows.is_empty():
		_cancel()
		return
	var remaining: Array[Control] = []
	for candidate in rows:
		if candidate != row:
			remaining.append(candidate)
	_target = 0
	for candidate in remaining:
		if _pointer.y > _viewport_rect(candidate).get_center().y:
			_target += 1
	var source_rect := _viewport_rect(row)
	var area := _viewport_rect(scroll) if is_instance_valid(scroll) else _viewport_rect(list_container)
	var line_y := source_rect.position.y
	if not remaining.is_empty():
		line_y = _viewport_rect(remaining[_target]).position.y if _target < remaining.size() else _viewport_rect(remaining.back()).end.y
	line_y = clampf(line_y, area.position.y + 2.0, area.end.y - 2.0)
	_visual.line_from = Vector2(maxf(source_rect.position.x, area.position.x) + 3, line_y)
	_visual.line_to = Vector2(minf(source_rect.end.x, area.end.x) - 3, line_y)
	var ghost_height := minf(source_rect.size.y, 48.0)
	# Preserve the press-time grab offset even at insertion boundaries and while
	# autoscrolling. The insertion marker is independent and may sit behind us.
	_visual.ghost = Rect2(Vector2(source_rect.position.x, _pointer.y - _ghost_grab_offset_y), Vector2(source_rect.size.x, ghost_height))
	_visual.caption = caption if not caption.is_empty() else "%d → %d" % [index + 1, _target + 1]
	_visual.queue_redraw()

func _process(delta: float) -> void:
	if not _dragging or not is_instance_valid(scroll):
		return
	var area := _viewport_rect(scroll)
	var speed := 0.0
	if _pointer.y < area.position.y + EDGE_ZONE:
		speed = -SCROLL_SPEED * clampf((area.position.y + EDGE_ZONE - _pointer.y) / EDGE_ZONE, 0.0, 1.0)
	elif _pointer.y > area.end.y - EDGE_ZONE:
		speed = SCROLL_SPEED * clampf((_pointer.y - area.end.y + EDGE_ZONE) / EDGE_ZONE, 0.0, 1.0)
	_scroll_remainder += speed * delta
	var movement := int(_scroll_remainder)
	_scroll_remainder -= movement
	if movement != 0:
		scroll.scroll_vertical += movement
	_update_target()

func _finish() -> void:
	if _dragging:
		_update_target()
	var from_index := index
	var to_index := _target
	var should_emit := _dragging and from_index != to_index and to_index >= 0
	_cancel()
	if should_emit:
		_emit_reorder.call_deferred(from_index, to_index)

func _emit_reorder(from_index: int, to_index: int) -> void:
	if not disabled and is_inside_tree():
		reordered.emit(from_index, to_index)

func _cancel() -> void:
	_pressed = false
	_dragging = false
	_touch_index = -1
	_target = -1
	set_process(false)
	set_process_input(false)
	if is_instance_valid(_visual_layer):
		_visual_layer.queue_free()
	_visual_layer = null
	_visual = null

func _on_focus_exited() -> void:
	_cancel()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_cancel()
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		_cancel()
