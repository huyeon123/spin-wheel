extends RefCounted
## One safe rectangle, converted once from OS pixels into each Control's space.
static var _unoccluded_client := Rect2()

# Native insets are sampled on Android's UI thread, never once per drawn frame.
# Only value types cross back to the Godot thread; Activity/View are reacquired.
static var _android_sample: Dictionary = {}
static var _android_sample_ms: int = -10000
static var _android_request_ms: int = -1000
static var _android_generation: int = 0
static var _android_pending: bool = false
static var _android_restore_pending: bool = false
static var _android_warned: bool = false


static func merge_safe_insets(client: Rect2, engine_safe: Rect2,
		native_bounds: Rect2, insets: Vector4) -> Rect2:
	## Insets are left/top/right/bottom in native window pixels. Intersect
	## rectangles instead of adding padding already present in the viewport.
	var safe := client.intersection(engine_safe) if engine_safe.has_area() else client
	if not safe.has_area(): safe = client
	if not native_bounds.has_area() or not insets.is_finite(): return safe
	var near := Vector2(maxf(0, insets.x), maxf(0, insets.y))
	var far := Vector2(maxf(0, insets.z), maxf(0, insets.w))
	var native_safe := Rect2(native_bounds.position + near, native_bounds.size - near - far)
	if not native_safe.has_area(): return safe
	var merged := safe.intersection(native_safe)
	return merged if merged.has_area() else safe


static func native_to_client(client: Rect2, render_bounds: Rect2, native_rect: Rect2) -> Rect2:
	## Native Android view pixels and Godot buffer pixels need not be equal.
	if not client.has_area() or not render_bounds.has_area() or not native_rect.has_area(): return client
	var clipped := render_bounds.intersection(native_rect)
	if not clipped.has_area(): return client
	var scale := client.size / render_bounds.size
	return Rect2(client.position + (clipped.position - render_bounds.position) * scale,
		clipped.size * scale).intersection(client)


static func android_safe_client(client: Rect2, engine_safe_native: Rect2, sample: Dictionary) -> Rect2:
	var native_bounds: Rect2 = sample.get("bounds", Rect2())
	var render_bounds: Rect2 = sample.get("render_bounds", Rect2())
	var insets: Vector4 = sample.get("insets", Vector4.ZERO)
	if not native_bounds.has_area() or not render_bounds.has_area(): return client
	var native_safe := merge_safe_insets(native_bounds, engine_safe_native, native_bounds, insets)
	var ime_bottom := maxf(0, float(sample.get("ime_bottom", 0.0)))
	if ime_bottom > 0: native_safe = exclude_keyboard(native_safe, native_bounds, ime_bottom)
	return native_to_client(client, render_bounds, native_safe)


static func control_to_client_transform(control: Control) -> Transform2D:
	## CanvasItem.get_screen_transform uses a popup transform which is identity
	## when subwindows are embedded (forced on Android). It drops window stretch!
	## Explicit viewport final × canvas transform retains the actual render scale.
	var transform := control.get_viewport().get_final_transform() * control.get_global_transform_with_canvas()
	transform.origin += Vector2(DisplayServer.window_get_position(control.get_window().get_window_id()))
	return transform


static func resume_fullscreen() -> void:
	if not OS.has_feature("android"): return
	# Drop stale activity geometry after rotation/resume. The old IME baseline
	# remains valid until the keyboard closes; safe_rect updates it then.
	_android_sample = {}
	_android_generation += 1
	_android_pending = false
	_android_request_ms = -1000
	_android_restore_pending = true
	_request_android_sample(Vector2(DisplayServer.window_get_position()))


static func _android_bridge_available() -> bool:
	return OS.has_feature("android") and ClassDB.class_exists("JavaClassWrapper") \
		and Engine.has_singleton("JavaClassWrapper") and Engine.has_singleton("AndroidRuntime")


static func _request_android_sample(origin: Vector2) -> void:
	if not _android_bridge_available():
		if OS.has_feature("android") and not _android_warned:
			_android_warned = true
			push_warning("Native Android insets unavailable; using Godot cutout/keyboard safe area.")
		return
	var now := Time.get_ticks_msec()
	if now - _android_request_ms < 200: return
	if _android_pending and now - _android_request_ms < 2000: return
	_android_request_ms = now
	_android_generation += 1
	var generation := _android_generation
	var wrapper := Engine.get_singleton("JavaClassWrapper")
	var runtime := Engine.get_singleton("AndroidRuntime")
	var activity: Variant = _java_call(wrapper, runtime, "getActivity")
	if activity == null: return
	var runnable: Variant = _java_call(wrapper, runtime, "createRunnableFromGodotCallable",
		[_sample_android_ui.bind(generation, origin, _android_restore_pending)])
	if runnable == null: return
	_android_pending = true
	_java_call(wrapper, activity, "runOnUiThread", [runnable])


static func java_truth(value: Variant) -> bool:
	# Godot 4.6 JNI can expose Java jboolean as an integer Variant. Comparing
	# that Variant directly to true is an invalid INT/BOOL operation in GDScript.
	if value is bool: return value
	if value is int: return value != 0
	return false


static func _java_call(wrapper: Object, target: Variant, method: StringName,
		args: Array = []) -> Variant:
	if not target is Object or not is_instance_valid(target): return null
	# Java methods aren't ordinary Object.has_method entries. Check the Java
	# reflection table first, and check Java exceptions after every invocation.
	var is_java: bool = target.has_method("has_java_method")
	if is_java:
		if not target.call("has_java_method", method): return null
	elif not target.has_method(method):
		return null
	var value: Variant = target.callv(method, args)
	if is_java and wrapper.call("get_exception") != null: return null
	return value


static func _java_wrap(wrapper: Object, name: String) -> Variant:
	# wrap is a Godot method. get_exception describes the last Java method,
	# so inspecting it here could reuse a stale exception from a prior sample.
	return wrapper.call("wrap", name)


static func _java_insets(wrapper: Object, value: Variant) -> Vector4:
	if value == null: return Vector4(NAN, NAN, NAN, NAN)
	# Godot 4.6 JavaObject exposes methods, not public instance fields. These
	# are public SDK fields; no private/hidden API or access override is used.
	var java_class: Variant = _java_call(wrapper, value, "getClass")
	var result := Vector4.ZERO
	var names := ["left", "top", "right", "bottom"]
	for i in range(4):
		var field: Variant = _java_call(wrapper, java_class, "getField", [names[i]])
		var number: Variant = _java_call(wrapper, field, "getInt", [value])
		if not number is int: return Vector4(NAN, NAN, NAN, NAN)
		result[i] = float(number)
	return result


static func _max_insets(a: Vector4, b: Vector4) -> Vector4:
	return Vector4(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z), maxf(a.w, b.w))


static func _sample_android_ui(generation: int, origin: Vector2, restore: bool) -> void:
	# Runs on Android UI thread. Do not access scenes, mutate layout or retain
	# Activity references here. Transfer only the finished measurement deferred.
	var sample := _read_android_ui(origin, restore)
	_finish_android_sample.call_deferred(generation, sample)


static func _read_android_ui(origin: Vector2, restore: bool) -> Dictionary:
	if not _android_bridge_available(): return {}
	var wrapper := Engine.get_singleton("JavaClassWrapper")
	var runtime := Engine.get_singleton("AndroidRuntime")
	var activity: Variant = _java_call(wrapper, runtime, "getActivity")
	if activity == null: return {}
	var version: Variant = _java_wrap(wrapper, "android.os.Build$VERSION")
	if version == null: return {}
	var sdk: Variant = version.get("SDK_INT")
	if not sdk is int: return {}
	var window: Variant = _java_call(wrapper, activity, "getWindow")
	var godot: Variant = _java_call(wrapper, activity, "getGodot")
	var restored := not restore
	if restore:
		_java_call(wrapper, godot, "enableEdgeToEdge", [true, true])
		_java_call(wrapper, godot, "enableImmersiveMode", [true, true])
		var cutout_ready := _enable_cutout_drawing(wrapper, window, sdk)
		restored = java_truth(_java_call(wrapper, godot, "isInEdgeToEdgeMode")) \
			and java_truth(_java_call(wrapper, godot, "isInImmersiveMode")) and cutout_ready
	var decor: Variant = _java_call(wrapper, window, "getDecorView")
	var root_insets: Variant = _java_call(wrapper, decor, "getRootWindowInsets")
	if root_insets == null: return {}
	var width: Variant = _java_call(wrapper, decor, "getWidth")
	var height: Variant = _java_call(wrapper, decor, "getHeight")
	if not width is int or not height is int or width <= 0 or height <= 0: return {}
	var native_bounds := Rect2(Vector2.ZERO, Vector2(width, height))
	if sdk >= 30:
		var manager: Variant = _java_call(wrapper, activity, "getWindowManager")
		var metrics: Variant = _java_call(wrapper, manager, "getCurrentWindowMetrics")
		var metric_rect := _java_rect(wrapper, _java_call(wrapper, metrics, "getBounds"))
		# Metrics include system/IME areas. Coordinates below are window-local,
		# so the display-relative metrics origin must not be added a second time.
		if metric_rect.has_area(): native_bounds.size = metric_rect.size
	var render_interface: Variant = _java_call(wrapper, godot, "getRenderView")
	var render_view: Variant = _java_call(wrapper, render_interface, "getView")
	var rect_class: Variant = _java_wrap(wrapper, "android.graphics.Rect")
	var render_rect: Variant = _java_call(wrapper, rect_class, "Rect")
	_java_call(wrapper, render_view, "getDrawingRect", [render_rect])
	_java_call(wrapper, decor, "offsetDescendantRectToMyCoords", [render_view, render_rect])
	var render_bounds := _java_rect(wrapper, render_rect)
	if not render_bounds.has_area(): return {}
	var insets := Vector4.ZERO
	var ime_bottom := 0.0
	var ime_known := false
	if sdk >= 30:
		var types: Variant = _java_wrap(wrapper, "android.view.WindowInsets$Type")
		var bars: Variant = _java_call(wrapper, types, "systemBars")
		var navigation: Variant = _java_call(wrapper, types, "navigationBars")
		var cutout: Variant = _java_call(wrapper, types, "displayCutout")
		var gestures: Variant = _java_call(wrapper, types, "mandatorySystemGestures")
		var ime: Variant = _java_call(wrapper, types, "ime")
		if not bars is int or not navigation is int or not cutout is int or not gestures is int or not ime is int: return {}
		var visible_bars := _java_insets(wrapper, _java_call(wrapper, root_insets, "getInsets", [bars]))
		var stable_edges := _java_insets(wrapper, _java_call(wrapper, root_insets,
			"getInsetsIgnoringVisibility", [navigation | cutout]))
		var gesture_edges := _java_insets(wrapper, _java_call(wrapper, root_insets,
			"getInsetsIgnoringVisibility", [gestures]))
		# Hidden status-bar space is not a second camera inset. Bottom navigation
		# and mandatory gestures remain reserved even while immersive bars hide.
		gesture_edges.y = 0
		if not visible_bars.is_finite() or not stable_edges.is_finite() or not gesture_edges.is_finite(): return {}
		insets = _max_insets(_max_insets(visible_bars, stable_edges), gesture_edges)
		var ime_edges := _java_insets(wrapper, _java_call(wrapper, root_insets, "getInsets", [ime]))
		ime_known = ime_edges.is_finite()
		if ime_known: ime_bottom = maxf(0, ime_edges.w)
	else:
		var suffixes := ["Left", "Top", "Right", "Bottom"]
		for i in range(4):
			var method := "getSystemWindowInset" if i == 1 else "getStableInset"
			var number: Variant = _java_call(wrapper, root_insets, method + suffixes[i])
			if number is int: insets[i] = maxf(0, float(number))
		var system_bottom: Variant = _java_call(wrapper, root_insets, "getSystemWindowInsetBottom")
		if system_bottom is int and float(system_bottom) > insets.w:
			ime_known = true
			ime_bottom = float(system_bottom)
		# A legacy zero/nav-only inset is ambiguous with adjustPan, so retain
		# Godot's height fallback instead of asserting that the IME is hidden.
		if sdk >= 28:
			var cutout: Variant = _java_call(wrapper, root_insets, "getDisplayCutout")
			for i in range(4):
				var number: Variant = _java_call(wrapper, cutout, "getSafeInset" + suffixes[i])
				if number is int: insets[i] = maxf(insets[i], float(number))
		if sdk >= 29:
			var gestures := _java_insets(wrapper, _java_call(wrapper, root_insets, "getMandatorySystemGestureInsets"))
			gestures.y = 0
			if gestures.is_finite(): insets = _max_insets(insets, gestures)
	if not insets.is_finite(): return {}
	return {"bounds": native_bounds, "render_bounds": render_bounds, "insets": insets,
		"ime_bottom": ime_bottom, "ime_known": ime_known, "restored": restored,
		"client_origin": origin}


static func _java_rect(wrapper: Object, value: Variant) -> Rect2:
	# Rect and Insets share four public int field names. Do not clamp signed
	# Rect origins: a render view can be translated/panned by the window manager.
	var edges := _java_insets(wrapper, value)
	if not edges.is_finite(): return Rect2()
	return Rect2(edges.x, edges.y, edges.z - edges.x, edges.w - edges.y)


static func _enable_cutout_drawing(wrapper: Object, window: Variant, sdk: int) -> bool:
	if sdk < 28: return true
	# Immersive + edge-to-edge alone may still letterbox at a camera on older
	# Android. Use the public window attribute, keeping controls separately safe.
	var constants: Variant = _java_wrap(wrapper, "android.view.WindowManager$LayoutParams")
	if constants == null: return false
	var name := "LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS" if sdk >= 30 else "LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES"
	var mode: Variant = constants.get(name)
	if not mode is int: return false
	var attributes: Variant = _java_call(wrapper, window, "getAttributes")
	var java_class: Variant = _java_call(wrapper, attributes, "getClass")
	var field: Variant = _java_call(wrapper, java_class, "getField", ["layoutInDisplayCutoutMode"])
	if field == null: return false
	_java_call(wrapper, field, "setInt", [attributes, mode])
	if _java_call(wrapper, field, "getInt", [attributes]) != mode: return false
	_java_call(wrapper, window, "setAttributes", [attributes])
	return wrapper.call("get_exception") == null


static func _finish_android_sample(generation: int, sample: Dictionary) -> void:
	if generation != _android_generation: return
	_android_pending = false
	if sample.is_empty(): return
	_android_sample = sample
	_android_sample_ms = Time.get_ticks_msec()
	if sample.get("restored", false): _android_restore_pending = false



static func screen_to_local(local_bounds: Rect2, local_to_screen: Transform2D,
		safe_screen: Rect2) -> Rect2:
	if not safe_screen.has_area() or is_zero_approx(local_to_screen.determinant()):
		return local_bounds
	var local_safe := local_to_screen.affine_inverse() * safe_screen
	var clipped := local_bounds.intersection(local_safe)
	# A missing/transient native measurement should not collapse the interface.
	return clipped if clipped.has_area() else local_bounds


static func safe_rect(control: Control) -> Rect2:
	var bounds := Rect2(Vector2.ZERO, control.size)
	# Desktop work-area fitting belongs to window_geometry.gd. Do not pad a
	# desktop client a second time for its taskbar or native title bar.
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return bounds
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var id := control.get_window().get_window_id()
	var client := Rect2(Vector2(DisplayServer.window_get_position(id)), Vector2(DisplayServer.window_get_size(id)))
	var native_ime_known := false
	if OS.has_feature("android"):
		_request_android_sample(client.position)
		if not _android_sample.is_empty() and Time.get_ticks_msec() - _android_sample_ms < 2000:
			var sample := _android_sample.duplicate()
			native_ime_known = sample.get("ime_known", false)
			if native_ime_known and float(sample.get("ime_bottom", 0)) <= 0:
				_unoccluded_client = client
			if not native_ime_known:
				sample["ime_bottom"] = maxf(0, float(DisplayServer.virtual_keyboard_get_height()))
			safe = android_safe_client(client, safe, sample)
			# Native sample already clips IME in its own window coordinates.
			return screen_to_local(bounds, control_to_client_transform(control), safe)
	var keyboard_height := float(DisplayServer.virtual_keyboard_get_height())
	if keyboard_height <= 0 or not _unoccluded_client.has_area() or not is_equal_approx(_unoccluded_client.size.x,client.size.x):
		_unoccluded_client = client
	if keyboard_height > 0:
		safe = exclude_keyboard(safe if safe.has_area() else client, _unoccluded_client, keyboard_height)
	return screen_to_local(bounds, control_to_client_transform(control), safe)


static func exclude_keyboard(safe_screen: Rect2, unoccluded_client_screen: Rect2,
		keyboard_height: float) -> Rect2:
	## The baseline is recorded before the IME opens. Its bottom stays fixed
	## whether the OS overlays the keyboard or resizes the render surface.
	## Intersecting (rather than subtracting from current height) avoids applying
	## the same keyboard twice when the viewport has already shrunk.
	if keyboard_height <= 0 or not unoccluded_client_screen.has_area():
		return safe_screen
	var keyboard_top := unoccluded_client_screen.end.y - keyboard_height
	var bottom := minf(safe_screen.end.y, keyboard_top)
	return Rect2(safe_screen.position, Vector2(safe_screen.size.x,
		maxf(1.0, bottom - safe_screen.position.y)))


static func inset_rect(rect: Rect2, horizontal: float, vertical: float) -> Rect2:
	var inset := Vector2(minf(horizontal, maxf(0, rect.size.x * 0.5 - 1)),
		minf(vertical, maxf(0, rect.size.y * 0.5 - 1)))
	return Rect2(rect.position + inset, rect.size - inset * 2)


static func compute_main(viewport_bounds: Rect2, safe_bounds: Rect2,
		status_height: float = 0.0, mobile: bool = false) -> Dictionary:
	var safe := viewport_bounds.intersection(safe_bounds)
	if not safe.has_area(): safe = viewport_bounds
	var compact := safe.size.y < 640.0
	var pad := 12.0 if compact else 24.0
	var inner := inset_rect(safe, pad, pad)
	if mobile:
		inner.position.y = safe.position.y + minf(12.0, safe.size.y * 0.1)
		inner.size.y = maxf(1.0, safe.end.y - minf(32.0, safe.size.y * 0.1) - inner.position.y)
	var gap := 8.0 if compact else 12.0
	var header_height := 48.0
	var result_height := 104.0
	var spin_height := 56.0
	var action_height := 48.0
	var action_gap := 12.0 if compact else 20.0
	var status_gap := gap if status_height > 0 else 0.0
	var footer_height := status_height + status_gap + spin_height + action_gap + action_height
	var column_width := minf(560.0, inner.size.x)
	var column_x := inner.get_center().x - column_width * 0.5
	var header := Rect2(column_x, inner.position.y, column_width, header_height)
	var result := Rect2(column_x, header.end.y + gap, column_width, result_height)
	var footer := Rect2(column_x, inner.end.y - footer_height, column_width, footer_height)
	var spin_width := minf(400.0, column_width)
	var spin := Rect2(inner.get_center().x - spin_width * 0.5,
		footer.position.y + status_height + status_gap, spin_width, spin_height)
	var actions := Rect2(column_x, spin.end.y + action_gap, column_width, action_height)
	var status := Rect2(column_x, footer.position.y, column_width, status_height)
	var wheel_top := result.end.y + gap
	var wheel_bottom := footer.position.y - gap
	var diameter := maxf(0.0, minf(520.0, minf(inner.size.x, wheel_bottom - wheel_top)))
	var center_y := viewport_bounds.get_center().y
	if diameter > 0:
		center_y = clampf(center_y, wheel_top + diameter * 0.5, wheel_bottom - diameter * 0.5)
	var wheel := Rect2(inner.get_center().x - diameter * 0.5, center_y - diameter * 0.5, diameter, diameter)
	return {"safe": safe, "header": header, "result": result, "footer": footer,
		"wheel": wheel, "status": status, "spin": spin, "actions": actions}
