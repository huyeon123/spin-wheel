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
	if now - _android_request_ms < 500: return
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
		result[i] = maxf(0, float(number))
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
	var restored := not restore
	if restore:
		var godot: Variant = _java_call(wrapper, activity, "getGodot")
		_java_call(wrapper, godot, "enableEdgeToEdge", [true, true])
		_java_call(wrapper, godot, "enableImmersiveMode", [true, true])
		var cutout_ready := _enable_cutout_drawing(wrapper, window, sdk)
		restored = _java_call(wrapper, godot, "isInEdgeToEdgeMode") == true \
			and _java_call(wrapper, godot, "isInImmersiveMode") == true and cutout_ready
	var decor: Variant = _java_call(wrapper, window, "getDecorView")
	var root_insets: Variant = _java_call(wrapper, decor, "getRootWindowInsets")
	# Null is normal before attachment; retry next poll without collapsing UI.
	if root_insets == null: return {}
	var width: Variant = _java_call(wrapper, decor, "getWidth")
	var height: Variant = _java_call(wrapper, decor, "getHeight")
	if not width is int or not height is int or width <= 0 or height <= 0: return {}
	var insets := Vector4.ZERO
	if sdk >= 30:
		var types: Variant = _java_wrap(wrapper, "android.view.WindowInsets$Type")
		var bars: Variant = _java_call(wrapper, types, "systemBars")
		var cutout: Variant = _java_call(wrapper, types, "displayCutout")
		var gestures: Variant = _java_call(wrapper, types, "mandatorySystemGestures")
		if not bars is int or not cutout is int or not gestures is int: return {}
		# Reserve measured bar space even while hidden so swipe-revealed bars
		# cannot obscure controls. IME is deliberately excluded from this mask.
		insets = _java_insets(wrapper, _java_call(wrapper, root_insets,
			"getInsetsIgnoringVisibility", [bars | cutout | gestures]))
	else:
		# API 24–29: stable insets exist from API 21 and exclude the IME.
		var suffixes := ["Left", "Top", "Right", "Bottom"]
		for i in range(4):
			var number: Variant = _java_call(wrapper, root_insets, "getStableInset" + suffixes[i])
			if number is int: insets[i] = maxf(0, float(number))
		if sdk >= 28:
			var cutout: Variant = _java_call(wrapper, root_insets, "getDisplayCutout")
			for i in range(4):
				var number: Variant = _java_call(wrapper, cutout, "getSafeInset" + suffixes[i])
				if number is int: insets[i] = maxf(insets[i], float(number))
		if sdk >= 29:
			insets = _max_insets(insets, _java_insets(wrapper,
				_java_call(wrapper, root_insets, "getMandatorySystemGestureInsets")))
	if not insets.is_finite(): return {}
	return {"bounds": Rect2(origin, Vector2(width, height)), "insets": insets, "restored": restored}


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
	if OS.has_feature("android"):
		_request_android_sample(client.position)
		if not _android_sample.is_empty() and Time.get_ticks_msec() - _android_sample_ms < 2000:
			var native_bounds: Rect2 = _android_sample["bounds"]
			# Ignore a pre-rotation or pre-resize sample until the UI thread catches up.
			if is_equal_approx(native_bounds.size.x, client.size.x) and native_bounds.position.is_equal_approx(client.position):
				safe = merge_safe_insets(client, safe, native_bounds, _android_sample["insets"])
	var keyboard_height := float(DisplayServer.virtual_keyboard_get_height())
	if keyboard_height <= 0 or not _unoccluded_client.has_area() or not is_equal_approx(_unoccluded_client.size.x,client.size.x):
		_unoccluded_client = client
	if keyboard_height > 0:
		safe = exclude_keyboard(safe if safe.has_area() else client, _unoccluded_client, keyboard_height)
	# get_screen_transform includes viewport stretching and the window origin.
	# Intersecting with our own bounds also handles a client already inset by OS.
	return screen_to_local(bounds, control.get_screen_transform(), safe)


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
		status_height: float = 0.0) -> Dictionary:
	var safe := viewport_bounds.intersection(safe_bounds)
	if not safe.has_area(): safe = viewport_bounds
	var compact := safe.size.y < 640.0
	var pad := 12.0 if compact else 24.0
	var inner := inset_rect(safe, pad, pad)
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
