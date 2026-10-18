extends SceneTree

const Geometry = preload("res://scripts/window_geometry.gd")
var checks := 0
var failures := 0


func _init() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func check_rect(label: String, usable: Rect2i, scale: float,
		borders: Vector4i = Geometry.UNKNOWN_DECORATIONS) -> void:
	var rect: Rect2i = Geometry.compute_rect(usable, scale, borders)
	var reserved: Vector4i = Geometry.fallback_decorations(scale) if borders == Geometry.UNKNOWN_DECORATIONS else borders
	var outer := Rect2i(rect.position - Vector2i(reserved.x, reserved.y),
		rect.size + Vector2i(reserved.x + reserved.z, reserved.y + reserved.w))
	check(rect.has_area(), label + ": positive client size")
	check(rect.size.y > rect.size.x, label + ": portrait")
	check(usable.encloses(outer), label + ": decorated frame fits usable bounds")
	check(absf(rect.size.x - rect.size.y * 0.6) <= 1.0, label + ": preserves 480:800 ratio")
	var center_error := Vector2(outer.position) + Vector2(outer.size) * 0.5 - (Vector2(usable.position) + Vector2(usable.size) * 0.5)
	check(absf(center_error.x) <= 0.5 and absf(center_error.y) <= 0.5, label + ": centers outer frame")
	var minimum: Vector2i = Geometry.compute_minimum(rect.size, scale)
	check(minimum.x <= rect.size.x and minimum.y <= rect.size.y, label + ": minimum cannot undo fitting")
	check(minimum.x > 0 and minimum.y > 0, label + ": minimum remains positive")
	check(rect.size.x <= 480 * Geometry.normalized_scale(scale) and rect.size.y <= 800 * Geometry.normalized_scale(scale), label + ": preferred cap respected")
	print("WINDOW_GEOMETRY ", label, " client=", rect, " minimum=", minimum)


func run() -> void:
	check_rect("1080p bottom taskbar", Rect2i(0, 0, 1920, 1040), 1.0)
	check_rect("1366x768 laptop taskbar", Rect2i(0, 0, 1366, 728), 1.0)
	check_rect("720p top panel", Rect2i(0, 32, 1280, 688), 1.0)
	check_rect("800x600 tiny desktop", Rect2i(0, 24, 800, 536), 1.0)
	check_rect("4K 200 percent", Rect2i(0, 0, 3840, 2080), 2.0)
	check_rect("1080p 150 percent", Rect2i(0, 0, 1920, 1016), 1.5)
	check_rect("fractional 125 percent", Rect2i(0, 30, 2560, 1370), 1.25)
	check_rect("left secondary monitor", Rect2i(-1920, 40, 1920, 1040), 1.0)
	check_rect("upper secondary monitor", Rect2i(320, -1440, 2560, 1392), 1.5)
	check_rect("right secondary scaled monitor", Rect2i(1920, 180, 2560, 1392), 2.0)
	check_rect("portrait monitor left dock", Rect2i(-1000, -200, 980, 1800), 1.0)
	check_rect("large native decorations", Rect2i(20, 48, 1360, 700), 1.5, Vector4i(20, 82, 20, 22))
	check_rect("borderless", Rect2i(120, 50, 480, 800), 1.0, Vector4i.ZERO)
	check_rect("very small usable area", Rect2i(-50, 80, 100, 160), 1.0)
	check_rect("bad scale falls back", Rect2i(0, 0, 1280, 700), NAN)
	check_rect("zero scale falls back", Rect2i(0, 0, 1280, 700), 0.0)
	check_rect("extreme DPI bounded", Rect2i(0, 0, 1920, 1040), 20.0)
	check(Geometry.compute_rect(Rect2i()).size == Vector2i.ZERO, "empty work area is rejected")
	check(Geometry.compute_rect(Rect2i(0, 0, -1, 800)).size == Vector2i.ZERO, "invalid work area is rejected")
	check(Geometry.compute_rect(Rect2i(0, 0, 8, 8)).size == Vector2i.ZERO, "impossible decorations are rejected instead of overflowing")
	check(Geometry.compute_rect(Rect2i(0, 0, 1920, 1040)).size == Vector2i(480, 800), "normal desktop uses mobile-like 480x800")
	for argument in ["--script", "-s", "--script=res://tests/test_layout.gd", "--editor", "-e", "--headless", "--resolution", "--resolution=1280x820", "--position", "--fullscreen", "-f", "--maximized", "-m", "--embedded-parent"]:
		check(Geometry.has_explicit_window_arguments(PackedStringArray(["--path", ".", argument])), argument + " prevents startup override")
	check(not Geometry.has_explicit_window_arguments(PackedStringArray(["--path", ".", "--rendering-method", "gl_compatibility"])), "ordinary launch can size itself")
	var previous_size := root.size
	var previous_minimum := root.min_size
	check(not Geometry.apply_desktop_startup(root), "script-driven test never resizes implicitly")
	check(root.size == previous_size and root.min_size == previous_minimum, "skipped runtime call preserves geometry")
	if DisplayServer.get_name() == "headless":
		check(not Geometry.apply_desktop_startup(root, true), "headless remains excluded even with test opt-in")
	check_sweep()
	if "--window-geometry-live" in OS.get_cmdline_user_args():
		await check_live_window()
	print("WINDOW_GEOMETRY_QA: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)


func check_sweep() -> void:
	# Synthetic monitor work areas also cover taskbars on every edge, very
	# short displays, fractional DPI, and monitors above/left of the primary.
	var cases := 0
	for width in [8, 17, 80, 240, 360, 480, 800, 1366, 1920, 3840, 7680]:
		for height in [8, 45, 90, 180, 320, 480, 600, 728, 1040, 2160, 4320]:
			for scale in [0.5, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0]:
				var area := Rect2i(-width + 37, -height + 19, width, height)
				var borders: Vector4i = Geometry.fallback_decorations(scale)
				var rect: Rect2i = Geometry.compute_rect(area, scale)
				cases += 1
				if not rect.has_area():
					check(width <= borders.x + borders.z or height <= borders.y + borders.w,
						"sweep rejects only genuinely impossible frames: " + str(area))
					continue
				var outer := Rect2i(rect.position - Vector2i(borders.x, borders.y),
					rect.size + Vector2i(borders.x + borders.z, borders.y + borders.w))
				check(area.encloses(outer), "sweep decorated frame fits: " + str(area) + " scale=" + str(scale))
				check(rect.size.x <= rect.size.y, "sweep portrait or one-pixel degenerate client")
				check(absf(rect.size.x - rect.size.y * 0.6) <= 1.0, "sweep aspect rounding within one pixel")
				var minimum: Vector2i = Geometry.compute_minimum(rect.size, scale)
				check(minimum.x <= rect.size.x and minimum.y <= rect.size.y, "sweep minimum stays inside fitted client")
	print("WINDOW_GEOMETRY_SWEEP: ", cases, " monitor/DPI combinations")


func check_live_window() -> void:
	# Optional native-window smoke test, never implied by running this suite:
	# godot --path . --script tests/test_window_geometry.gd -- --window-geometry-live
	if DisplayServer.get_name() == "headless":
		print("WINDOW_GEOMETRY_LIVE: skipped, no native window in headless mode")
		return
	for frame in range(3):
		await process_frame
	check(Geometry.apply_desktop_startup(root, true), "explicit native-window test applies sizing")
	for frame in range(3):
		await process_frame
	var id := root.get_window_id()
	var screen := DisplayServer.window_get_current_screen(id)
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var actual := Rect2i(DisplayServer.window_get_position_with_decorations(id),
		DisplayServer.window_get_size_with_decorations(id))
	check(root.size.y > root.size.x, "native startup window is portrait")
	if DisplayServer.get_name() != "Wayland":
		check(usable.encloses(actual), "actual decorated native frame fits work area")
	check(not root.unresizable and root.max_size == Vector2i.ZERO, "native window remains freely resizable")
	var target := root.size + Vector2i(40, 0)
	root.size = target
	for frame in range(3):
		await process_frame
	check(root.size == target, "manual width change works without an aspect-ratio lock")
	print("WINDOW_GEOMETRY_LIVE: workarea=", usable, " outer=", actual, " resized=", root.size)
