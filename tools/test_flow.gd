extends SceneTree
## Midterm stage 1 checks: GameFlow scene order, restart, pause reset and the KillZone.
## Run: godot --headless --path . -s tools/test_flow.gd   (exit code 0 = all PASS, 1 = any FAIL)

const WATCHDOG_SECONDS: float = 30.0
const KILL_ZONE_SCENE: String = "res://scenes/props/kill_zone.tscn"

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

func _flow() -> Node:
	return root.get_node("GameFlow")

## change_scene_to_file swaps the scene at the end of the frame; wait until it is in place.
func _settle() -> void:
	for i in 3:
		await process_frame

func _scene_path() -> String:
	return current_scene.scene_file_path if current_scene != null else "<none>"

func _run() -> void:
	await _test_order()
	await _test_restart()
	await _test_pause_reset()
	await _test_kill_zone()
	var code: int = 1 if _failures > 0 else 0
	print("RESULT: %s, %d failure(s), exit code %d" % ["PASS" if code == 0 else "FAIL", _failures, code])
	# like GameFlow.quit_game: stop the music and let the audio thread release it, or it leaks at exit
	root.get_node("MusicPlayer").call("stop_all")
	await create_timer(0.15, true, false, true).timeout
	quit(code)

func _test_order() -> void:
	var flow: Node = _flow()
	var levels: Array[String] = flow.LEVELS
	var error: Error = flow.start_game()
	await _settle()
	_check("start_game loads level_1", error == OK and _scene_path() == levels[0], _scene_path())
	_check("start_game sets current_index 0", flow.current_index == 0, str(flow.current_index))
	for i in range(1, levels.size()):
		flow.next_level(2)
		await _settle()
		_check("next_level -> %s" % levels[i].get_file(), _scene_path() == levels[i], _scene_path())
	flow.next_level(2)
	await _settle()
	_check("next_level after the last level -> win screen", _scene_path() == flow.WIN_SCENE, _scene_path())
	_check("coins banked across levels", flow.total_coins == 2 * levels.size(), str(flow.total_coins))
	flow.go_to_menu()
	await _settle()
	_check("go_to_menu -> main menu", _scene_path() == flow.MENU_SCENE, _scene_path())

func _test_restart() -> void:
	var flow: Node = _flow()
	flow.start_game()
	await _settle()
	flow.next_level()
	await _settle()
	var before: Node = current_scene
	var error: Error = flow.restart_level()
	await _settle()
	_check("restart_level reloads the same level", error == OK and _scene_path() == flow.LEVELS[1], _scene_path())
	_check("restart_level makes a fresh instance", current_scene != before and not is_instance_valid(before))

func _test_pause_reset() -> void:
	var flow: Node = _flow()
	paused = true
	flow.restart_level()
	_check("pause cleared at the scene change call", not paused)
	await _settle()
	_check("pause still off in the new scene", not paused)

func _test_kill_zone() -> void:
	var flow: Node = _flow()
	flow.start_game()
	await _settle()
	var player: CharacterBody3D = get_first_node_in_group("player") as CharacterBody3D
	var health: Health = player.get_node("Health") as Health
	health.take_damage(1)
	_check("player invincible after a hit", health.is_invincible())
	var zone: Area3D = (load(KILL_ZONE_SCENE) as PackedScene).instantiate() as Area3D
	current_scene.add_child(zone)
	zone.global_position = player.global_position
	for i in 5:
		await physics_frame
	_check("KillZone kills through invincibility", health.is_dead(), "hp=%d" % health.current)
	flow.go_to_menu()
	await _settle()
