extends SceneTree
## Assignment 7 checks: PlayerInputHandler, on-screen stick, no raw keys in game code.
## Run: godot --headless --path . -s tools/test_a7.gd   (exit code 0 = all PASS, 1 = any FAIL)

const SCRIPTS_DIR: String = "res://scripts"
## The single place allowed to name a raw mouse button (VirtualStick.is_primary_click).
const RAW_INPUT_EXCEPTION: String = "res://scripts/ui/virtual_stick.gd"
const MAP_SCENE: String = "res://scenes/map.tscn"
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
	map.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
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

func _count_slashes(parent: Node) -> int:
	var count: int = 0
	for child in parent.get_children():
		if child is Slash:
			count += 1
	return count
