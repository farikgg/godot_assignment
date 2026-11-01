extends SceneTree
## Screenshots of the UI on every DevicePreview preset: main menu, hero select, HUD (level 1),
## pause, the arena HUD with the boss bar, win screen. Needs a real window (not --headless):
##   godot --path . -s dev/capture_screens.gd
##   godot --path . -s dev/capture_screens.gd -- --out=docs/screenshots --presets=notch_19_5_9
## PNGs go to screenshots/ (git-ignored) unless --out says otherwise; the safe-area overlay
## (notch plate, yellow dashed frame) is drawn on them.

const LEVEL_1: String = "res://scenes/levels/level_1.tscn"
const ARENA: String = "res://scenes/levels/level_3_boss.tscn"
const MENU: String = "res://scenes/main_menu.tscn"
const WIN: String = "res://scenes/win_screen.tscn"
## Frames to wait after a window resize or a scene change before the picture settles.
const SETTLE_FRAMES: int = 30

var _out_dir: String = "res://screenshots"
var _presets: Array[String] = []

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("capture_screens: needs a window, run without --headless")
		quit(1)
		return
	_run.call_deferred()

func _parse_args() -> void:
	var preview: Node = root.get_node("DevicePreview")
	_presets.assign(preview.get("ORDER"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = "res://" + arg.get_slice("=", 1).trim_prefix("res://")
		elif arg.begins_with("--presets="):
			_presets.assign(arg.get_slice("=", 1).split(",", false))

func _run() -> void:
	_parse_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	var preview: Node = root.get_node("DevicePreview")
	var flow: Node = root.get_node("GameFlow")
	for preset in _presets:
		preview.call("apply_preset", preset)
		await _settle()

		await _open(MENU)
		_save(preset, "1_menu")
		current_scene.call("_on_button_heroes_pressed")
		await _settle()
		_save(preset, "2_hero_select")

		flow.call("start_game")
		await _settle()
		_save(preset, "3_hud")
		_press_pause()
		await _settle()
		_save(preset, "4_pause")
		_press_pause()
		await _settle()

		flow.set("current_index", 2)
		flow.call("restart_level")
		# the boss wakes after 2 s; wait for its toast and bar
		await create_timer(2.5, true, false, true).timeout
		_save(preset, "5_arena")

		await _open(WIN)
		_save(preset, "6_win")
	preview.call("clear_preset")
	print("capture_screens: saved to %s" % ProjectSettings.globalize_path(_out_dir))
	flow.call("quit_game", 0)

func _open(path: String) -> void:
	root.get_node("GameFlow").call("_change_scene", path)
	await _settle()

func _press_pause() -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = &"pause"
		event.pressed = pressed
		Input.parse_input_event(event)

func _settle() -> void:
	for i in SETTLE_FRAMES:
		await process_frame

func _save(preset: String, screen: String) -> void:
	var image: Image = root.get_texture().get_image()
	var path: String = "%s/%s_%s.png" % [_out_dir, preset, screen]
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("capture_screens: cannot save %s (%s)" % [path, error_string(error)])
	else:
		print("  %s  %dx%d" % [path.get_file(), image.get_width(), image.get_height()])
