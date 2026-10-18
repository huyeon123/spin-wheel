extends PanelContainer
## Release-only card taps coexist with scroll gestures and explicit child actions.
signal activated
const TAP_SLOP := 8.0
var scroll: ScrollContainer
var _tracking := false
var _pointer_id := -1
var _origin := Vector2.ZERO
var _scroll_origin := Vector2.ZERO
var _moved := false
var _suppress_mouse_until := 0

func _ready() -> void:
 add_to_group("preset_tap_cards")
 mouse_filter = Control.MOUSE_FILTER_PASS
 focus_mode = Control.FOCUS_ALL
 mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 set_process_input(false)
 visibility_changed.connect(func(): if not is_visible_in_tree(): _cancel())

func _gui_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
  accept_event(); _emit_activation.call_deferred(); return
 if event is InputEventScreenTouch and event.pressed and not _tracking:
  _suppress_mouse_until = Time.get_ticks_msec() + 600
  _begin(get_global_transform_with_canvas() * event.position,event.index)
 elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _tracking:
  if event.device == InputEvent.DEVICE_ID_EMULATION and Time.get_ticks_msec() < _suppress_mouse_until: return
  _begin(get_global_transform_with_canvas() * event.position,-1)
 # Deliberately do not accept pointer-down: the ancestor ScrollContainer needs it.

func _begin(point: Vector2, pointer_id: int) -> void:
 if not _available() or _child_action_at(self,point): return
 _tracking = true; _pointer_id = pointer_id; _origin = point; _moved = false
 _scroll_origin = Vector2(scroll.scroll_horizontal,scroll.scroll_vertical) if is_instance_valid(scroll) else Vector2.ZERO
 set_process_input(true)

func _input(event: InputEvent) -> void:
 if not _tracking: return
 if event is InputEventScreenTouch and event.pressed and event.index != _pointer_id:
  _cancel()
  return
 if event is InputEventScreenDrag and event.index == _pointer_id: _move(event.position)
 elif event is InputEventMouseMotion and _pointer_id == -1: _move(event.position)
 elif event is InputEventScreenTouch and event.index == _pointer_id and not event.pressed:
  _suppress_mouse_until = Time.get_ticks_msec() + 600
  if event.canceled: _cancel()
  else: _finish(event.position)
 elif event is InputEventMouseButton and _pointer_id == -1 and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: _finish(event.position)
 elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: _moved = true

func _move(point: Vector2) -> void:
 if point.distance_to(_origin) > TAP_SLOP: _moved = true

func _finish(point: Vector2) -> void:
 _move(point)
 var scrolled := is_instance_valid(scroll) and Vector2(scroll.scroll_horizontal,scroll.scroll_vertical) != _scroll_origin
 var can_activate := _available() and not _moved and not scrolled and is_visible_in_tree() and get_global_rect().has_point(point) and not _child_action_at(self,point)
 _cancel()
 if can_activate:
  get_viewport().set_input_as_handled()
  _emit_activation.call_deferred()

func _cancel() -> void:
 _tracking = false
 set_process_input(false)

func _child_action_at(node: Node, point: Vector2) -> bool:
 for child in node.get_children():
  if child is Control and child.is_visible_in_tree():
   if (child is BaseButton or child.focus_mode == Control.FOCUS_ALL) and child.get_global_rect().has_point(point): return true
   if _child_action_at(child,point): return true
 return false

func _available() -> bool:
 if not is_inside_tree() or not is_visible_in_tree(): return false
 var ancestor := get_parent()
 while ancestor != null:
  if ancestor.has_meta("is_layer"):
   return ancestor._is_topmost() and not ancestor._closing
  ancestor = ancestor.get_parent()
 return false

func _emit_activation() -> void:
 if _available(): activated.emit()

func _notification(what: int) -> void:
 if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
  _cancel()
