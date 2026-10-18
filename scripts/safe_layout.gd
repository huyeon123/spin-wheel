extends RefCounted
## One safe rectangle, converted once from OS pixels into each Control's space.
static var _unoccluded_client := Rect2()


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
