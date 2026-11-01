extends CanvasLayer
## Autoload DevicePreview (debug builds only) — Godot's stand-in for Unity's Device Simulator.
## Gives the window a device's proportions (scaled down to fit the monitor) and makes every
## SafeArea use that device's safe area, then draws the cut-outs over the game: a dark plate where
## the notch is, a tint over all unsafe strips and a yellow dashed frame around the safe area.
##
## Choose a preset with `-- --device=notch_19_5_9` on the command line or cycle with F8
## (off → phone_16_9 → notch_19_5_9 → tablet_4_3 → off). F9 shows / hides the overlay.

signal preset_changed

## size: device resolution in pixels; insets: left, top, right, bottom of the cut-outs in pixels.
const PRESETS: Dictionary = {
	"phone_16_9": {"size": Vector2i(1920, 1080), "insets": Vector4i(0, 0, 0, 0)},
	"notch_19_5_9": {"size": Vector2i(2532, 1170), "insets": Vector4i(141, 0, 141, 63)},
	"tablet_4_3": {"size": Vector2i(2048, 1536), "insets": Vector4i(0, 0, 0, 0)},
}
const ORDER: Array[String] = ["phone_16_9", "notch_19_5_9", "tablet_4_3"]
## Share of the monitor's usable area the preview window may take.
const SCREEN_FILL: float = 0.9

var _preset: String = ""
var _original_size: Vector2i = Vector2i.ZERO
var _overlay: Control

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process_input(false)
		return
	_overlay = _SafeAreaOverlay.new()
	_overlay.name = "Overlay"
	add_child(_overlay)
	_original_size = DisplayServer.window_get_size()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--device="):
			apply_preset.call_deferred(arg.get_slice("=", 1))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_next_device", false):
		cycle_preset()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_safe_area_overlay", false):
		_overlay.visible = not _overlay.visible
		get_viewport().set_input_as_handled()

func is_active() -> bool:
	return _preset != ""

func current_preset() -> String:
	return _preset

## Switches to a preset by name (see PRESETS); an empty name turns the preview off.
func apply_preset(preset_name: String) -> void:
	if not OS.is_debug_build():
		return
	if preset_name.is_empty():
		clear_preset()
		return
	if not PRESETS.has(preset_name):
		push_error("DevicePreview: unknown preset '%s' (%s)" % [preset_name, ", ".join(ORDER)])
		return
	_preset = preset_name
	_fit_window(PRESETS[preset_name]["size"])
	DisplayServer.window_set_title("%s — %s" % [ProjectSettings.get_setting("application/config/name"), preset_name])
	_announce()

func clear_preset() -> void:
	_preset = ""
	if _original_size != Vector2i.ZERO:
		DisplayServer.window_set_size(_original_size)
	DisplayServer.window_set_title(ProjectSettings.get_setting("application/config/name"))
	_announce()

func cycle_preset() -> void:
	var index: int = ORDER.find(_preset)
	if index == ORDER.size() - 1:
		clear_preset()
	else:
		apply_preset(ORDER[index + 1])

## The device's safe rect mapped onto the current window, in the window's physical pixels.
func safe_rect_in_window() -> Rect2:
	# the root Window's size, as SafeArea reads it (DisplayServer reports 0 × 0 when headless)
	var window_size := Vector2(get_tree().root.size)
	if not is_active():
		return Rect2(Vector2.ZERO, window_size)
	var device := Vector2(PRESETS[_preset]["size"])
	var insets: Vector4i = PRESETS[_preset]["insets"]
	var k: Vector2 = window_size / device
	var top_left := Vector2(insets.x, insets.y) * k
	var bottom_right := Vector2(insets.z, insets.w) * k
	return Rect2(top_left, window_size - top_left - bottom_right)

# the device's proportions, as large as fits on this monitor
func _fit_window(device_size: Vector2i) -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var fit: float = minf(1.0, minf(usable.size.x * SCREEN_FILL / device_size.x, usable.size.y * SCREEN_FILL / device_size.y))
	var size := Vector2i(roundi(device_size.x * fit), roundi(device_size.y * fit))
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)

# the OS applies a new window size a frame later: tell SafeAreas now and once more after it
func _announce() -> void:
	preset_changed.emit()
	if _overlay != null:
		_overlay.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	preset_changed.emit()
	if _overlay != null:
		_overlay.queue_redraw()


## Draws the cut-outs and the safe-area frame of the active preset over everything.
class _SafeAreaOverlay extends Control:
	const UNSAFE_TINT := Color(0.0, 0.0, 0.0, 0.3)
	const NOTCH_COLOR := Color(0.02, 0.02, 0.03, 0.85)
	const FRAME_COLOR := Color(1.0, 0.85, 0.1, 0.95)
	const DASH: float = 14.0
	const LINE_WIDTH: float = 3.0
	## The notch as drawn: its share of the screen height, centred on the left edge.
	const NOTCH_HEIGHT_SHARE: float = 0.38

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		get_viewport().size_changed.connect(queue_redraw)

	func _draw() -> void:
		var preview: Node = get_parent()
		if not preview.call("is_active"):
			return
		var window_size := Vector2(get_tree().root.size)
		var screen: Vector2 = get_viewport_rect().size
		var insets: Vector4 = SafeArea.compute_insets(preview.call("safe_rect_in_window"), window_size, screen)
		var safe := Rect2(Vector2(insets.x, insets.y), screen - Vector2(insets.x + insets.z, insets.y + insets.w))
		# everything outside the safe rect
		draw_rect(Rect2(0.0, 0.0, insets.x, screen.y), UNSAFE_TINT)
		draw_rect(Rect2(screen.x - insets.z, 0.0, insets.z, screen.y), UNSAFE_TINT)
		draw_rect(Rect2(insets.x, 0.0, safe.size.x, insets.y), UNSAFE_TINT)
		draw_rect(Rect2(insets.x, screen.y - insets.w, safe.size.x, insets.w), UNSAFE_TINT)
		# the notch on the left edge (landscape) and the home indicator at the bottom
		if insets.x > 0.0:
			var height: float = screen.y * NOTCH_HEIGHT_SHARE
			draw_rect(Rect2(0.0, (screen.y - height) * 0.5, insets.x * 0.8, height), NOTCH_COLOR)
		if insets.w > 0.0:
			var bar := Vector2(screen.x * 0.25, maxf(insets.w * 0.15, 4.0))
			draw_rect(Rect2((screen.x - bar.x) * 0.5, screen.y - insets.w * 0.5 - bar.y * 0.5, bar.x, bar.y),
				Color(1.0, 1.0, 1.0, 0.6))
		# dashed frame of the safe area
		var corners: Array[Vector2] = [safe.position, Vector2(safe.end.x, safe.position.y), safe.end,
			Vector2(safe.position.x, safe.end.y)]
		for i in corners.size():
			draw_dashed_line(corners[i], corners[(i + 1) % corners.size()], FRAME_COLOR, LINE_WIDTH, DASH)
