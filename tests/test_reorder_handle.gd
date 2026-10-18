extends SceneTree

const Handle = preload("res://scripts/reorder_handle.gd")
var observed: Array = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var host := Control.new()
	root.add_child(host)
	host.size = Vector2(400, 600)
	var scroll := ScrollContainer.new()
	host.add_child(scroll)
	scroll.size = Vector2(350, 180)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	list.custom_minimum_size.x = 300
	var heading := Label.new()
	heading.text = "Heading ignored"
	list.add_child(heading)
	var handles: Array = []
	for i in range(5):
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(300, 60)
		list.add_child(row)
		var handle := Handle.new()
		row.add_child(handle)
		handle.configure(list, row, i, scroll)
		handle.reordered.connect(func(a: int, b: int): observed.append([a, b]))
		handles.append(handle)
	await process_frame
	await process_frame
	var handle = handles[0]
	_check(handle._rows().size() == 5, "Non-row children must be ignored")
	var start: Vector2 = handle._viewport_rect(handle).get_center()
	handle._begin(start, -1)
	handle._move(start + Vector2(0, 7))
	_check(not handle._dragging, "Threshold prevents accidental drags")
	handle._finish()
	await process_frame
	_check(observed.is_empty(), "Click must not reorder")
	handle._begin(start, -1)
	handle._move(Vector2(start.x, 1000))
	_check(handle._dragging and handle._target == 4)
	_check(is_instance_valid(handle._visual), "Drag overlay should exist")
	handle._finish()
	_check(observed.is_empty(), "Emission must be deferred")
	await process_frame
	_check(observed == [[0, 4]])
	observed.clear()
	handle._begin(start, -1)
	handle._move(start + Vector2(0, 12))
	handle._finish()
	await process_frame
	_check(observed.is_empty(), "Same-position drag must be a no-op")
	handle._begin(start, 2)
	handle._move(Vector2(start.x, 1000))
	var cancel := InputEventScreenTouch.new()
	cancel.index = 2
	cancel.canceled = true
	handle._input(cancel)
	await process_frame
	_check(not handle._pressed and observed.is_empty(), "Touch cancellation must not reorder")
	handle._begin(start, -1)
	handle._move(Vector2(start.x, 1000))
	handle.disabled = true
	_check(not handle._pressed and not is_instance_valid(handle._visual))
	handle.disabled = false
	var key := InputEventKey.new()
	key.keycode = KEY_DOWN
	key.pressed = true
	key.alt_pressed = true
	handle._gui_input(key)
	await process_frame
	_check(observed == [[0, 1]], "Alt+Down should reorder")
	observed.clear()
	handle._begin(start, -1)
	handle._move(Vector2(start.x, 1000))
	handle._process(0.1)
	_check(scroll.scroll_vertical > 0, "Bottom-edge drag must scroll")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	handle._input(escape)
	await process_frame
	_check(not handle._pressed and observed.is_empty())
	# Dispatch through the real viewport GUI hit-testing and _input pipeline.
	scroll.scroll_vertical = 0
	await process_frame
	await process_frame
	start = handle._viewport_rect(handle).get_center()
	_mouse_move(start)
	_mouse_button(start, true)
	_check(handle._pressed and handle._touch_index == -1, "GUI mouse press hits only the handle")
	_mouse_move(start + Vector2(0, 7))
	_check(not handle._dragging, "Dispatched mouse respects threshold")
	_mouse_move(Vector2(start.x, 150))
	_check(handle._dragging, "Dispatched mouse movement begins drag")
	_mouse_button(Vector2(start.x, 150), false)
	await process_frame
	_check(observed == [[0, 1]], "Dispatched mouse drag emits correct final position")
	observed.clear()
	_mouse_move(start)
	_mouse_button(start, true)
	_mouse_move(Vector2(start.x, 150))
	root.push_input(escape, true)
	_mouse_button(Vector2(start.x, 150), false)
	await process_frame
	_check(not handle._pressed and observed.is_empty(), "Dispatched Escape cancels without mutation")
	_mouse_move(start)
	_mouse_button(start, true)
	_mouse_move(Vector2(start.x, 150))
	handle.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_mouse_button(Vector2(start.x, 150), false)
	await process_frame
	_check(not handle._pressed and not is_instance_valid(handle._visual) and observed.is_empty(), "Application focus loss cancels active mouse drag")
	# Real touch starts through GUI; synthetic mouse events cannot replace or release it.
	_touch(start, 0, true)
	_check(handle._pressed and handle._touch_index == 0, "GUI direct touch captures its touch index")
	_mouse_button(start, true, InputEvent.DEVICE_ID_EMULATION)
	_check(handle._touch_index == 0, "Emulated mouse duplicate does not replace touch")
	_touch(start, 1, true)
	_touch_drag(Vector2(start.x, 150), 1)
	_check(handle._touch_index == 0 and not handle._dragging, "Second finger cannot move primary drag")
	_touch(Vector2(start.x, 150), 1, false)
	_check(handle._pressed, "Second finger release cannot finish primary drag")
	_touch_drag(Vector2(start.x, 150), 0)
	_check(handle._dragging and handle._target == 1, "Primary touch moves to expected target")
	_mouse_button(Vector2(start.x, 150), false, InputEvent.DEVICE_ID_EMULATION)
	_check(handle._pressed and observed.is_empty(), "Emulated mouse release cannot finish touch")
	_touch(Vector2(start.x, 150), 0, false)
	await process_frame
	_check(observed == [[0, 1]], "Touch and emulated events emit exactly one reorder")
	observed.clear()
	_touch(start, 3, true)
	_touch_drag(Vector2(start.x, 150), 3)
	_touch(Vector2(start.x, 150), 3, false, true)
	await process_frame
	_check(not handle._pressed and observed.is_empty(), "Dispatched touch cancellation does not reorder")
	_touch(start, 4, true)
	_touch_drag(Vector2(start.x, 150), 4)
	handle.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_touch(Vector2(start.x, 150), 4, false)
	await process_frame
	_check(not handle._pressed and observed.is_empty(), "Window focus loss cancels touch")
	_mouse_move(start)
	_mouse_button(start, true)
	_mouse_move(Vector2(start.x, 150))
	handle.hide()
	_mouse_button(Vector2(start.x, 150), false)
	await process_frame
	_check(not handle._pressed and observed.is_empty(), "Hiding handle cancels active drag")
	host.queue_free()
	await process_frame
	print("PASS: %d reorder handle checks; direct interaction and viewport mouse/touch dispatch" % checks)
	quit()

func _check(condition: bool, message: String = "") -> void:
	checks += 1
	if not condition:
		push_error("Check %d failed: %s" % [checks, message])
		quit(1)
		assert(condition, message)

func _mouse_button(position: Vector2, pressed: bool, device: int = 0) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.device = device
	root.push_input(event, true)

func _mouse_move(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	root.push_input(event, true)

func _touch(position: Vector2, finger: int, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.index = finger
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func _touch_drag(position: Vector2, finger: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position = position
	event.index = finger
	root.push_input(event, true)
