extends SceneTree
## Assignment 7 checks: PlayerInputHandler, on-screen stick, no raw keys in game code, HUD toast.
## Run: godot --headless --path . -s tools/test_a7.gd   (exit code 0 = all PASS, 1 = any FAIL)

const SCRIPTS_DIR: String = "res://scripts"
## The single place allowed to name a raw mouse button (VirtualStick.is_primary_click).
const RAW_INPUT_EXCEPTION: String = "res://scripts/ui/virtual_stick.gd"
const MAP_SCENE: String = "res://scenes/levels/level_1.tscn"
const SWORD_SCENE: String = "res://scenes/weapons/sword.tscn"
const WATCHDOG_SECONDS: float = 30.0

var _failures: int = 0

func _initialize() -> void:
	create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	_run.call_deferred()

func _on_watchdog() -> void:
	_check("finished before watchdog", false, "%.0f s" % WATCHDOG_SECONDS)
	quit(1)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", label, ("  (" + detail + ")") if detail != "" else ""])

func _run() -> void:
	await _test_handler()
	_test_no_raw_keys()
	await _test_on_screen_stick()
	await _test_arrows_and_camera_keys()
	await _test_camera_spam()
	await _test_toast()
	var code: int = 1 if _failures > 0 else 0
	print("RESULT: %s, %d failure(s), exit code %d" % ["PASS" if code == 0 else "FAIL", _failures, code])
	quit(code)

func _axis(axis: JoyAxis, value: float, device: int = 0) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.device = device
	motion.axis = axis
	motion.axis_value = value
	Input.parse_input_event(motion)

func _key(code: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = pressed
	Input.parse_input_event(key)

func _test_handler() -> void:
	var handler := PlayerInputHandler.new()
	root.add_child(handler)
	await process_frame

	_axis(JOY_AXIS_LEFT_X, 1.0)
	await process_frame
	_check("joypad axis 0 = 1.0 -> move.x = 1", is_equal_approx(handler.move.x, 1.0) and is_zero_approx(handler.move.y),
		"move=%s" % handler.move)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await process_frame

	_key(KEY_D, true)
	await process_frame
	_check("key D -> move.x = 1", is_equal_approx(handler.move.x, 1.0), "move=%s" % handler.move)

	_axis(JOY_AXIS_LEFT_X, 1.0)
	_axis(JOY_AXIS_LEFT_Y, 1.0)
	await process_frame
	_check("D + stick together stay within length 1", handler.move.length() <= 1.0 + 0.0001,
		"move=%s len=%.3f" % [handler.move, handler.move.length()])
	_key(KEY_D, false)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await process_frame
	_check("all released -> move = 0", handler.move == Vector2.ZERO, "move=%s" % handler.move)

	var jumps: Array[int] = [0]
	handler.jump_pressed.connect(func() -> void: jumps[0] += 1)
	var jump := InputEventAction.new()
	jump.action = &"jump"
	jump.pressed = true
	Input.parse_input_event(jump)
	await process_frame
	_check("InputEventAction(jump) emits jump_pressed", jumps[0] == 1, "emitted %d time(s)" % jumps[0])
	handler.queue_free()
	await process_frame

func _gd_files(dir: String, out: Array[String]) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		_gd_files(dir.path_join(sub), out)

func _test_no_raw_keys() -> void:
	# engine constants only (KEY_A, KEY_SPACE...), not names that merely contain "KEY_"
	var pattern := RegEx.create_from_string("Input\\.is_key_pressed|(?<![A-Za-z0-9_])KEY_[A-Z0-9_]+|(?<![A-Za-z0-9_])MOUSE_BUTTON_[A-Z_]+")
	var files: Array[String] = []
	_gd_files(SCRIPTS_DIR, files)
	var hits: Array[String] = []
	for path in files:
		if path == RAW_INPUT_EXCEPTION:
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var found: RegExMatch = pattern.search(lines[i])
			if found != null:
				hits.append("%s:%d %s" % [path.get_file(), i + 1, found.get_string()])
	_check("no Input.is_key_pressed / KEY_* / MOUSE_BUTTON_* in scripts/ (except virtual_stick.gd)",
		hits.is_empty(), "%d files scanned%s" % [files.size(), (", hits: " + ", ".join(hits)) if not hits.is_empty() else ""])

func _test_on_screen_stick() -> void:
	var map: Node3D = (load(MAP_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(map)
	current_scene = map
	var spawner: Node = map.get_node_or_null("Spawner")
	if spawner != null:
		spawner.process_mode = Node.PROCESS_MODE_DISABLED
	var handler: PlayerInputHandler = map.get_node("Player/InputHandler") as PlayerInputHandler
	var stick: VirtualStick = map.get_node_or_null("TouchControls/Root/Stick") as VirtualStick
	if handler == null or stick == null:
		_check("map has Player/InputHandler and TouchControls/Root/Stick", false)
		return
	for i in 5:
		await process_frame
	# events are posted in window pixels; the stick lives in the stretched canvas
	var to_window: Transform2D = root.get_final_transform()
	var centre: Vector2 = to_window * stick.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = centre
	touch.pressed = true
	Input.parse_input_event(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = to_window * (stick.get_global_rect().get_center() + Vector2(stick.max_radius, 0))
	Input.parse_input_event(drag)
	await process_frame
	_check("on-screen stick drives move through joypad emulation", handler.move.x > 0.95, "move=%s" % handler.move)
	touch = touch.duplicate() as InputEventScreenTouch
	touch.pressed = false
	Input.parse_input_event(touch)
	await process_frame
	_check("releasing the stick sends 0", handler.move == Vector2.ZERO, "move=%s" % handler.move)

	# with emulate_touch_from_mouse on, a click on the stick is a touch, never an attack
	var player: Node = map.get_node("Player")
	player.call("equip_weapon", load(SWORD_SCENE) as PackedScene)
	await process_frame
	await process_frame
	var slashes_before: int = _count_slashes(map)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = centre
	click.pressed = true
	Input.parse_input_event(click)
	await physics_frame
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	await physics_frame
	_check("a click on the stick does not attack", _count_slashes(map) == slashes_before, "slashes=%d" % _count_slashes(map))
	await create_timer(0.6).timeout
	var elsewhere := InputEventMouseButton.new()
	elsewhere.button_index = MOUSE_BUTTON_LEFT
	elsewhere.position = to_window * Vector2(960, 400)
	elsewhere.pressed = true
	Input.parse_input_event(elsewhere)
	await physics_frame
	_check("a click away from the controls still attacks", _count_slashes(map) == slashes_before + 1, "slashes=%d" % _count_slashes(map))
	current_scene = null
	map.queue_free()
	await process_frame

func _test_arrows_and_camera_keys() -> void:
	var map: Node3D = (load(MAP_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(map)
	current_scene = map
	var spawner: Node = map.get_node_or_null("Spawner")
	if spawner != null:
		spawner.process_mode = Node.PROCESS_MODE_DISABLED
	var handler: PlayerInputHandler = map.get_node("Player/InputHandler") as PlayerInputHandler
	var pivot: Node3D = map.get_node("CameraPivot") as Node3D
	for i in 5:
		await process_frame
	var yaw_before: float = pivot.rotation_degrees.y

	_key(KEY_RIGHT, true)
	await process_frame
	var move_x: float = handler.move.x
	await create_timer(0.5).timeout
	_key(KEY_RIGHT, false)
	await process_frame
	_check("Right arrow moves (move.x = 1) and does not turn the camera",
		is_equal_approx(move_x, 1.0) and is_equal_approx(pivot.rotation_degrees.y, yaw_before),
		"move.x=%.2f yaw %.1f -> %.1f" % [move_x, yaw_before, pivot.rotation_degrees.y])

	_key(KEY_Q, true)
	_key(KEY_Q, false)
	await create_timer(0.5).timeout
	var after_q: float = pivot.rotation_degrees.y
	_key(KEY_E, true)
	_key(KEY_E, false)
	await create_timer(0.5).timeout
	var after_e: float = pivot.rotation_degrees.y
	_check("Q turns the camera left, E turns it back",
		is_equal_approx(fposmod(after_q - yaw_before, 360.0), 270.0) and is_equal_approx(fposmod(after_e, 360.0), fposmod(yaw_before, 360.0)),
		"yaw %.1f -> Q %.1f -> E %.1f" % [yaw_before, after_q, after_e])
	current_scene = null
	map.queue_free()
	await process_frame

func _camera_action(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = &"camera_right"
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)

# yaw change folded into (-180, 180]
func _yaw_delta(before: float, after: float) -> float:
	return wrapf(after - before, -180.0, 180.0)

## Repeated camera presses (one frame, faster than a turn, a finger's repeated touch) turn exactly 90°.
func _test_camera_spam() -> void:
	var map: Node3D = (load(MAP_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(map)
	current_scene = map
	var pivot: Node3D = map.get_node("CameraPivot") as Node3D
	var turn_time: float = pivot.get("turn_duration")
	for i in 5:
		await process_frame

	var yaw: float = pivot.rotation_degrees.y
	for i in 5:
		_camera_action(true)
		_camera_action(false)
	await create_timer(turn_time + 0.25).timeout
	_check("5 camera_right in one frame turn exactly 90°", is_equal_approx(_yaw_delta(yaw, pivot.rotation_degrees.y), 90.0),
		"%.1f -> %.1f" % [yaw, pivot.rotation_degrees.y])

	yaw = pivot.rotation_degrees.y
	for i in 5:
		_camera_action(true)
		_camera_action(false)
		await create_timer(turn_time / 6.0).timeout
	await create_timer(turn_time + 0.25).timeout
	_check("5 camera_right faster than a turn give exactly 90°", is_equal_approx(_yaw_delta(yaw, pivot.rotation_degrees.y), 90.0),
		"%.1f -> %.1f" % [yaw, pivot.rotation_degrees.y])

	# the on-screen button: a finger's pressed event arriving again must not press twice
	var button: Control = map.get_node("TouchControls/Root/CameraRightButton") as Control
	var at: Vector2 = root.get_final_transform() * button.get_global_rect().get_center()
	yaw = pivot.rotation_degrees.y
	for i in 3:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = at
		touch.pressed = true
		Input.parse_input_event(touch)
	await process_frame
	var held: bool = (button as TouchActionButton).is_pressed()
	var lift := InputEventScreenTouch.new()
	lift.index = 0
	lift.position = at
	lift.pressed = false
	Input.parse_input_event(lift)
	await create_timer(turn_time + 0.25).timeout
	_check("repeated touches of one finger on the camera button turn exactly 90°",
		held and not (button as TouchActionButton).is_pressed() and is_equal_approx(_yaw_delta(yaw, pivot.rotation_degrees.y), 90.0),
		"held=%s yaw %.1f -> %.1f" % [held, yaw, pivot.rotation_degrees.y])
	current_scene = null
	map.queue_free()
	await process_frame

func _test_toast() -> void:
	var map: Node3D = (load(MAP_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(map)
	current_scene = map
	var spawner: Node = map.get_node_or_null("Spawner")
	if spawner != null:
		spawner.process_mode = Node.PROCESS_MODE_DISABLED
	var hud: Hud = map.get_node("HUD") as Hud
	var toast: Toast = hud.get_node_or_null("%Toast") as Toast
	if toast == null:
		_check("HUD has a Toast", false)
		return
	var screen_width: float = toast.get_viewport_rect().size.x
	var long_text: String = "Решётка опущена. Продержись, пока не стихнет обвал. " .repeat(3)
	hud.show_message(long_text, 2.0)
	for i in 3:
		await process_frame
	var rect: Rect2 = toast.panel_rect()
	var lines: int = (toast.get_node("Panel/Text") as Label).get_line_count()
	_check("a long message wraps within 40% of the screen", rect.size.x <= screen_width * Toast.MAX_WIDTH_SHARE + 1.0 and lines > 1,
		"width %.0f of %.0f, %d lines" % [rect.size.x, screen_width, lines])
	var hud_rect: Rect2 = (hud.get_node("HudPanel") as Control).get_global_rect()
	_check("the toast does not cover the hearts / gold panel", not rect.intersects(hud_rect), "toast %s hud %s" % [rect, hud_rect])

	hud.show_message("Первое", 1.0)
	await create_timer(0.8).timeout
	hud.show_message("Второе", 1.0)
	await create_timer(0.6).timeout
	var plates: int = toast.find_children("*", "PanelContainer", true, false).size()
	_check("a new toast replaces the text and restarts the timer", toast.current_text() == "Второе" and plates == 1,
		"text=%s plates=%d" % [toast.current_text(), plates])

	hud.show_message("Игровое", 0.3)
	paused = true
	await create_timer(1.2, true).timeout
	var frozen: bool = toast.is_showing()
	paused = false
	await create_timer(0.6).timeout
	paused = true
	hud.show_message("Пауза", 0.3)
	await create_timer(1.2, true).timeout
	var finished_on_pause: bool = not toast.is_showing()
	paused = false
	_check("a game toast freezes on pause, one raised on pause plays out", frozen and finished_on_pause,
		"game toast kept=%s pause toast finished=%s" % [frozen, finished_on_pause])
	current_scene = null
	map.queue_free()
	await process_frame

func _count_slashes(parent: Node) -> int:
	var count: int = 0
	for child in parent.get_children():
		if child is Slash:
			count += 1
	return count
