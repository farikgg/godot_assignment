extends CanvasLayer
## Autoload FpsOverlay: FPS, frame time, draw calls, objects, particles, memory and time_scale in a
## small panel at the top centre. Exists in debug builds, and in a release export only when the
## preset lists the custom feature `fps_overlay` (tester APKs). Hidden until toggled: F3
## (action debug_fps_overlay), a long press in the top-left corner on a touch screen, or
## `-- --fps-overlay` on the command line. It never takes input: the gesture is only watched.
## Also registers custom monitors (juice/*) for the editor's Debugger > Monitors on a device.

const TESTER_FEATURE: String = "fps_overlay"
const CMDLINE_FLAG: String = "--fps-overlay"
const TOGGLE_ACTION: StringName = &"debug_fps_overlay"
## Under DevicePreview's frame (128), above every game layer (pause menu is 10).
const LAYER: int = 127
const FONT_SIZE: int = 22
const PANEL_TOP_PX: float = 130.0
const BYTES_PER_MB: float = 1048576.0
const USEC_PER_SEC: float = 1000000.0
const MSEC_PER_SEC: float = 1000.0
const MONITOR_TIME_SCALE: StringName = &"juice/time_scale"
const MONITOR_PARTICLES: StringName = &"juice/particles_emitting"
const NO_TOUCH: int = -1

var _data: JuiceData
var _available: bool = false
var _label: Label
var _panel: PanelContainer
# frame timing over one refresh window, in real time (hit stop scales delta, not this)
var _window_start_usec: int = 0
var _last_frame_usec: int = 0
var _frames: int = 0
var _worst_frame_usec: int = 0
# long press in the corner
var _touch_index: int = NO_TOUCH
var _touch_start: Vector2 = Vector2.ZERO
var _touch_start_usec: int = 0

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_data = JuiceData.get_data()
	_available = (OS.is_debug_build() or OS.has_feature(TESTER_FEATURE)) and _data.overlay_ok()
	visible = false
	if not _available:
		set_process(false)
		set_process_input(false)
		return
	_build()
	Performance.add_custom_monitor(MONITOR_TIME_SCALE, _monitor_time_scale)
	Performance.add_custom_monitor(MONITOR_PARTICLES, count_emitting_particles)
	if OS.get_cmdline_user_args().has(CMDLINE_FLAG):
		set_shown(true)

func _exit_tree() -> void:
	for id in [MONITOR_TIME_SCALE, MONITOR_PARTICLES]:
		if Performance.has_custom_monitor(id):
			Performance.remove_custom_monitor(id)

func is_available() -> bool:
	return _available

func set_shown(value: bool) -> void:
	if not _available:
		return
	visible = value
	_reset_window()
	if value:
		_refresh()

func toggle() -> void:
	set_shown(not visible)

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _touch_index != NO_TOUCH and now - _touch_start_usec >= int(_data.overlay_long_press_sec * USEC_PER_SEC):
		_touch_index = NO_TOUCH
		toggle()
	if not visible:
		return
	if _last_frame_usec != 0:
		_worst_frame_usec = maxi(_worst_frame_usec, now - _last_frame_usec)
	_last_frame_usec = now
	_frames += 1
	if now - _window_start_usec >= int(_data.overlay_refresh_sec * USEC_PER_SEC):
		_refresh()
		_reset_window()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION, false):
		toggle()
		get_viewport().set_input_as_handled()
		return
	# watched, never handled: the touch still reaches the game and the HUD
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and _touch_index == NO_TOUCH and _in_corner(touch.position):
			_touch_index = touch.index
			_touch_start = touch.position
			_touch_start_usec = Time.get_ticks_usec()
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = NO_TOUCH
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _touch_index and drag.position.distance_to(_touch_start) > _data.overlay_press_slop_px:
			_touch_index = NO_TOUCH

## GPU and CPU particle nodes in the tree that are emitting (also the juice/particles monitor).
func count_emitting_particles() -> int:
	var count: int = 0
	for node in get_tree().root.find_children("*", "GPUParticles3D", true, false):
		if (node as GPUParticles3D).emitting:
			count += 1
	for node in get_tree().root.find_children("*", "CPUParticles3D", true, false):
		if (node as CPUParticles3D).emitting:
			count += 1
	return count

func _monitor_time_scale() -> float:
	return Engine.time_scale

func _in_corner(point: Vector2) -> bool:
	return point.x <= _data.overlay_corner_px and point.y <= _data.overlay_corner_px

func _reset_window() -> void:
	_window_start_usec = Time.get_ticks_usec()
	_last_frame_usec = 0
	_frames = 0
	_worst_frame_usec = 0

func _refresh() -> void:
	var elapsed_sec: float = float(Time.get_ticks_usec() - _window_start_usec) / USEC_PER_SEC
	var fps: float = float(_frames) / elapsed_sec if elapsed_sec > 0.0 and _frames > 0 \
		else Performance.get_monitor(Performance.TIME_FPS)
	var frame_ms: float = MSEC_PER_SEC / fps if fps > 0.0 else 0.0
	var worst_ms: float = float(_worst_frame_usec) / MSEC_PER_SEC
	var static_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / BYTES_PER_MB
	var video_mb: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / BYTES_PER_MB
	_label.text = "\n".join([
		"FPS %.0f   frame %.1f ms (worst %.1f)" % [fps, frame_ms, worst_ms],
		"cpu %.1f ms   physics %.1f ms" % [
			Performance.get_monitor(Performance.TIME_PROCESS) * MSEC_PER_SEC,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * MSEC_PER_SEC],
		"draw calls %d   objects %d   prims %d" % [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)],
		"nodes %d   particles %d" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), count_emitting_particles()],
		# static memory is only tracked in debug builds; a release build shows 0
		"mem %s   video %.0f MB   time_scale %.2f" % [
			"%.0f MB" % static_mb if static_mb > 0.0 else "n/a", video_mb, Engine.time_scale],
	])

func _build() -> void:
	var safe := SafeArea.new()
	safe.name = "SafeArea"
	add_child(safe)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(root)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.position.y = PANEL_TOP_PX
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	_panel.add_child(_label)
