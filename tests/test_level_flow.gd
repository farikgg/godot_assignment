extends SceneTree
## Headless check of the level catalog, unlocking and the real level flow. Run from the project:
##   Godot --headless --path . -s res://tests/test_level_flow.gd
## Uses user://test_flow_save.json; the real save is not touched.

const TEST_PATH: String = "user://test_flow_save.json"
## Level.EXIT_DELAY plus a margin.
const EXIT_WAIT_SEC: float = 2.5

var _failures: int = 0
var _save: Node
var _flow: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_save = root.get_node("SaveGame")
	_flow = root.get_node("GameFlow")
	_save.save_path = TEST_PATH
	_cleanup()
	_save.load_game()

	print("catalog")
	_check(_flow.catalog.validate().is_empty(), "catalog has no problems")
	_check(_flow.level_ids() == [&"level_1", &"level_2", &"level_3_boss"], "three level ids")
	_check(_flow.default_unlocked_level_ids() == [&"level_1"], "only level_1 open by default")
	_check(_flow.catalog.index_of_scene("res://scenes/levels/level_2.tscn") == 1, "scene path -> index")
	var uid: int = ResourceLoader.get_resource_uid("res://scenes/levels/level_2.tscn")
	_check(_flow.catalog.index_of_scene(ResourceUID.id_to_text(uid)) == 1, "uid:// path -> same index")

	print("unlocking follows next_level_id")
	_check(_flow.start_level(1) == ERR_UNAUTHORIZED, "locked level_2 refused")
	_check(_flow.current_index == -1, "refusal changes nothing")
	_save.record_level_result(&"level_2", 1, 10.0)
	_check(_save.is_level_unlocked(&"level_3_boss"), "level_2 done -> level_3_boss open (order-independent)")
	_save.reset()
	_check(_save.unlocked_levels == [&"level_1"], "reset closes them again")

	print("real flow: level_1 -> exit -> level_2")
	_check(_flow.start_level(0) == OK, "start_level(0)")
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.scene_file_path.ends_with("level_1.tscn"), "level_1 loaded")
	_check(_flow.current_index == 0 and _flow.run_from_start, "index 0, run from start")
	current_scene.call("_on_exit_reached")
	await create_timer(EXIT_WAIT_SEC).timeout
	await process_frame
	_check(current_scene != null and current_scene.scene_file_path.ends_with("level_2.tscn"), "level_2 loaded")
	_check(_flow.current_index == 1, "index 1")
	_check(_save.is_level_unlocked(&"level_2") and _save.best_score.has(&"level_1"), "level_2 unlocked, level_1 recorded")
	var on_disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	_check(on_disk is Dictionary and (on_disk["unlocked_levels"] as Array).has("level_2"), "unlock saved to disk")
	_check(_save.best_time_sec.get(&"level_1", 0.0) > 0.0, "time recorded")

	print("F6-style registration")
	_flow.current_index = -1
	_flow.register_level("res://scenes/levels/level_3_boss.tscn")
	_check(_flow.current_index == 2 and _flow.is_last_level(), "register_level finds the arena, last level")

	_flow.go_to_menu()
	await process_frame
	print("Level flow tests: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	# not GameFlow.quit_game: it would save the test file again after the cleanup
	root.get_node("MusicPlayer").stop_all()
	await create_timer(0.2).timeout
	_cleanup()
	quit(1 if _failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)

func _cleanup() -> void:
	for path in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
