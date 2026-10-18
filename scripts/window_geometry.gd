extends RefCounted
## Desktop startup sizing only. Nothing runs when this script is loaded.
## DisplayServer screen/work-area/window geometry is already in pixels. Scale
## the preferred size and padding, never the supplied screen rectangle again.
## https://docs.godotengine.org/en/4.6/classes/class_displayserver.html

const PORTRAIT_SIZE := Vector2i(480, 800)
const PREFERRED_MINIMUM := Vector2i(360, 640)
const EDGE_MARGIN := 16.0
const UNKNOWN_DECORATIONS := Vector4i(-1, -1, -1, -1)


static func normalized_scale(scale: float) -> float:
	if not is_finite(scale) or scale <= 0.0:
		return 1.0
	return clampf(scale, 0.5, 4.0)


static func fallback_decorations(scale: float = 1.0) -> Vector4i:
	var factor := normalized_scale(scale)
	# Left, top/title bar, right, bottom. Used before native borders are known.
	return Vector4i(ceili(8 * factor), ceili(36 * factor), ceili(8 * factor), ceili(8 * factor))


static func compute_rect(usable: Rect2i, scale: float = 1.0,
		decorations: Vector4i = UNKNOWN_DECORATIONS) -> Rect2i:
	## Returns a CLIENT rectangle centered with its reserved native decorations.
	## All input/output coordinates share DisplayServer's virtual-desktop space,
	## including negative origins. An empty result means no valid window fits.
	if usable.size.x <= 0 or usable.size.y <= 0:
		return Rect2i()
	var factor := normalized_scale(scale)
	var borders := _valid_decorations(decorations, factor)
	var border_size := Vector2i(borders.x + borders.z, borders.y + borders.w)
	var room := usable.size - border_size
	if room.x < 1 or room.y < 1:
		return Rect2i()
	# Reduce margins on unusually small screens instead of imposing a minimum
	# that could force the frame outside the usable area.
	var requested_margin := ceili(EDGE_MARGIN * factor)
	var margin := Vector2i(mini(requested_margin, (room.x - 1) / 2),
		mini(requested_margin, (room.y - 1) / 2))
	var available := room - margin * 2
	var preferred := Vector2(PORTRAIT_SIZE) * factor
	var fit := minf(1.0, minf(available.x / preferred.x, available.y / preferred.y))
	var client := Vector2i(maxi(1, floori(preferred.x * fit)),
		maxi(1, floori(preferred.y * fit)))
	var outer_size := client + border_size
	var outer_position := usable.position + Vector2i(
		floori((usable.size.x - outer_size.x) * 0.5),
		floori((usable.size.y - outer_size.y) * 0.5))
	return Rect2i(outer_position + Vector2i(borders.x, borders.y), client)


static func compute_minimum(client_size: Vector2i, scale: float = 1.0) -> Vector2i:
	## A small monitor must never be enlarged again by the project minimum.
	## This is only a minimum; no maximum size or aspect-ratio lock is imposed.
	var preferred := Vector2(PREFERRED_MINIMUM) * normalized_scale(scale)
	return Vector2i(maxi(1, mini(client_size.x, floori(preferred.x))),
		maxi(1, mini(client_size.y, floori(preferred.y))))


static func has_explicit_window_arguments(arguments: PackedStringArray) -> bool:
	# Preserve test/screenshot harness geometry and editor-embedded game windows.
	for argument in arguments:
		var option := argument.get_slice("=", 0)
		if option in ["--script", "-s", "--editor", "-e", "--headless",
				"--resolution", "--position", "--fullscreen", "-f", "--maximized",
				"-m", "--embedded-parent"]:
			return true
	return false


static func apply_desktop_startup(window: Window, explicit_test: bool = false) -> bool:
	## Call once from main._ready(). Script-driven tests are skipped unless they
	## explicitly opt in; mobile/web/headless are always skipped, even with opt-in.
	if window == null or Engine.is_editor_hint() or OS.has_feature("mobile") or OS.has_feature("web"):
		return false
	var server := DisplayServer.get_name()
	if server not in ["Windows", "macOS", "X11", "Wayland"]:
		return false
	if not explicit_test and has_explicit_window_arguments(OS.get_cmdline_args()):
		return false
	if window.is_embedded() or window.get_window_id() != DisplayServer.MAIN_WINDOW_ID:
		return false
	if window.mode != Window.MODE_WINDOWED:
		return false
	var window_id := window.get_window_id()
	var screen := DisplayServer.window_get_current_screen(window_id)
	if screen < 0 or screen >= DisplayServer.get_screen_count():
		return false
	var usable := DisplayServer.screen_get_usable_rect(screen)
	if not usable.has_area():
		# Do not invent primary-monitor bounds when the work area is unavailable.
		return false
	var scale := _screen_scale(server, screen)
	var borders := _window_decorations(window, scale)
	# Wayland does not expose the work area or allow applications to position
	# windows. Leave placement to the compositor and reserve extra panel space.
	if server == "Wayland":
		var panel_reserve := mini(ceili(48 * scale), maxi(0, usable.size.y / 4))
		usable.position.y += panel_reserve
		usable.size.y -= panel_reserve * 2
	var rect := compute_rect(usable, scale, borders)
	if not rect.has_area():
		return false
	# Remove an oversized old minimum before shrinking the window. Window
	# properties keep Godot's Viewport in sync with the native window.
	window.unresizable = false
	window.min_size = compute_minimum(rect.size, scale)
	window.max_size = Vector2i.ZERO
	window.size = rect.size
	if server != "Wayland":
		window.position = rect.position
	return true


static func _valid_decorations(value: Vector4i, scale: float) -> Vector4i:
	if value == UNKNOWN_DECORATIONS:
		return fallback_decorations(scale)
	return Vector4i(maxi(0, value.x), maxi(0, value.y), maxi(0, value.z), maxi(0, value.w))


static func _screen_scale(server: String, screen: int) -> float:
	# Wayland's fractional scale is accurate only with SCREEN_OF_MAIN_WINDOW.
	var scale_screen := DisplayServer.SCREEN_OF_MAIN_WINDOW if server == "Wayland" else screen
	var scale := DisplayServer.screen_get_scale(scale_screen)
	# Godot returns 1.0 for screen_get_scale on Windows and X11. DPI is a
	# bounded best-effort fallback there, not an extra multiplier on bounds.
	if server in ["Windows", "X11"]:
		scale = maxf(1.0, DisplayServer.screen_get_dpi(screen) / 96.0)
	return normalized_scale(scale)


static func _window_decorations(window: Window, scale: float) -> Vector4i:
	if window.borderless:
		return Vector4i.ZERO
	var id := window.get_window_id()
	var total := DisplayServer.window_get_size_with_decorations(id) - DisplayServer.window_get_size(id)
	var offset := DisplayServer.window_get_position(id) - DisplayServer.window_get_position_with_decorations(id)
	var measured := Vector4i(maxi(0, offset.x), maxi(0, offset.y),
		maxi(0, total.x - offset.x), maxi(0, total.y - offset.y))
	var reserve := fallback_decorations(scale)
	# Some window managers report zero until after the first map/configure.
	# Reserve each edge conservatively without throwing away larger real borders.
	return Vector4i(maxi(measured.x, reserve.x), maxi(measured.y, reserve.y),
		maxi(measured.z, reserve.z), maxi(measured.w, reserve.w))
