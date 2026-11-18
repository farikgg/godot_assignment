extends SceneTree
## Headless check of SaveGame. Run from the project folder:
##   Godot --headless --path . -s res://tests/test_save_game.gd
## Uses user://test_save.json; the real save is not touched.

const TEST_PATH: String = "user://test_save.json"

var _failures: int = 0
var _save: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_save = root.get_node("SaveGame")
	_save.save_path = TEST_PATH
	_test_missing()
	_test_empty()
	_test_garbage()
	_test_not_object()
	_test_wrong_types()
	_test_round_trip()
	_test_tmp_recovery()
	_test_locked_hero()
	_test_results_and_reset()
	_cleanup()
	print("SaveGame tests: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)

func _write(text: String, path: String = TEST_PATH) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _cleanup() -> void:
	for path in [TEST_PATH, TEST_PATH + _save.TMP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _defaults() -> Dictionary:
	_cleanup()
	_save.load_game()
	return _save.to_dict()

func _test_missing() -> void:
	print("missing file")
	_cleanup()
	var error: Error = _save.load_game()
	_check(error == ERR_FILE_NOT_FOUND, "returns ERR_FILE_NOT_FOUND")
	_check(_save.player_name == _save.DEFAULT_NAME, "default name")
	_check(_save.unlocked_levels == [&"level_1"], "only level_1 unlocked")
	_check(_save.selected_hero != &"" and _save.is_hero_unlocked(_save.selected_hero), "an unlocked hero selected")
	_check(_save.music_volume == 1.0 and _save.sfx_volume == 1.0, "full volumes")

func _test_empty() -> void:
	print("empty file")
	var defaults: Dictionary = _defaults()
	_write("")
	_check(_save.load_game() == ERR_FILE_UNRECOGNIZED, "returns ERR_FILE_UNRECOGNIZED")
	_check(_save.to_dict() == defaults, "all defaults")

func _test_garbage() -> void:
	print("garbage text")
	var defaults: Dictionary = _defaults()
	_write("{{ this is not json ]] \u0000ÿ")
	_check(_save.load_game() == ERR_FILE_UNRECOGNIZED, "returns ERR_FILE_UNRECOGNIZED")
	_check(_save.to_dict() == defaults, "all defaults")

func _test_not_object() -> void:
	print("JSON that is not an object")
	var defaults: Dictionary = _defaults()
	_write("[1, 2, 3]")
	_save.load_game()
	_check(_save.to_dict() == defaults, "array: all defaults")
	_write("42")
	_save.load_game()
	_check(_save.to_dict() == defaults, "number: all defaults")

func _test_wrong_types() -> void:
	print("valid JSON, wrong types and values")
	_write(JSON.stringify({
		"version": "1",
		"player_name": 42,
		"selected_hero": ["male_a"],
		"unlocked_heroes": "all",
		"unlocked_levels": [1, "nope", "level_2", "level_2", null],
		"best_score": {"level_1": 3.5, "level_2": -1, "zzz": 4, "level_3_boss": 7.0},
		"best_time_sec": {"level_1": "fast", "level_2": 12.5, "level_3_boss": -3},
		"best_total": 1e300,
		"total_coins": -5,
		"music_volume": 2.0,
		"sfx_volume": null,
		"cheat_mode": true,
	}))
	_check(_save.load_game() == OK, "file read")
	_check(_save.player_name == _save.DEFAULT_NAME, "name: number -> default")
	_check(_save.unlocked_heroes == _save._default_heroes(), "heroes: string -> default")
	_check(_save.is_hero_unlocked(_save.selected_hero), "selected hero valid")
	_check(_save.unlocked_levels.size() == 2 and _save.is_level_unlocked(&"level_1")
		and _save.is_level_unlocked(&"level_2"), "levels: junk dropped, duplicate merged, level_1 kept")
	_check(_save.best_score == {&"level_3_boss": 7}, "best_score: 7.0 -> 7, rest dropped")
	_check(_save.best_score[&"level_3_boss"] is int, "best_score value is int")
	_check(_save.best_time_sec == {&"level_2": 12.5}, "best_time_sec: only the valid time")
	_check(_save.best_total == 0 and _save.total_coins == 0, "out-of-range counters -> 0")
	_check(_save.music_volume == 1.0 and _save.sfx_volume == 1.0, "bad volumes -> 1.0")

func _test_round_trip() -> void:
	print("valid file round trip")
	_cleanup()
	_save.load_game()
	_save.set_player_name("Тест")
	_save.set_music_volume(0.25)
	_save.set_sfx_volume(0.0)
	_save.unlocked_levels.append(&"level_2")
	_save.record_level_result(&"level_1", 6, 42.5)
	_save.record_run_total(17)
	_check(_save.save_game() == OK, "save_game OK")
	_check(not FileAccess.file_exists(TEST_PATH + _save.TMP_SUFFIX), "no .tmp left")
	var before: Dictionary = _save.to_dict()
	# change memory only (no save), so the reload must come from the file
	_save.player_name = "Other"
	_save.total_coins = 0
	_save.best_score.clear()
	_save.load_game()
	_check(_save.to_dict() == before, "reloaded state equals saved state")
	_check(_save.total_coins == 6 and _save.best_score[&"level_1"] == 6, "coins and record")
	_check(is_equal_approx(_save.best_time_sec[&"level_1"], 42.5), "time")
	var bus: int = AudioServer.get_bus_index(&"SFX")
	_check(AudioServer.is_bus_mute(bus), "SFX bus muted at volume 0")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	_check(parsed is Dictionary and (parsed as Dictionary)["unlocked_levels"] is Array, "unlocked_levels stored as a list")

func _test_tmp_recovery() -> void:
	print("only the .tmp survived")
	_cleanup()
	_write(JSON.stringify({"version": 1, "player_name": "Tmp", "total_coins": 3}), TEST_PATH + _save.TMP_SUFFIX)
	_save.load_game()
	_check(_save.player_name == "Tmp" and _save.total_coins == 3, "read from .tmp")

func _test_locked_hero() -> void:
	print("unknown hero")
	_write(JSON.stringify({"version": 1, "selected_hero": "no_such_hero", "unlocked_heroes": ["no_such_hero"]}))
	_save.load_game()
	_check(_save.is_hero_unlocked(_save.selected_hero), "unknown selected hero replaced by an unlocked one")
	_check(not _save.unlocked_heroes.has(&"no_such_hero"), "unknown hero dropped from unlocked_heroes")
	_check(not _save.set_selected_hero(&"no_such_hero"), "set_selected_hero refuses an unknown id")

func _test_results_and_reset() -> void:
	print("results and reset")
	_cleanup()
	_save.load_game()
	_save.set_player_name("Keep")
	_save.set_music_volume(0.5)
	_save.record_level_result(&"level_1", 5, 30.0)
	_save.record_level_result(&"level_1", 3, 20.0)
	_check(_save.best_score[&"level_1"] == 5, "best coins kept")
	_check(is_equal_approx(_save.best_time_sec[&"level_1"], 20.0), "best time is the fastest")
	_check(_save.total_coins == 8, "coins banked from both")
	_save.record_level_result(&"unknown_level", 99, 1.0)
	_check(not _save.best_score.has(&"unknown_level"), "unknown level ignored")
	_save.reset()
	_check(_save.best_score.is_empty() and _save.total_coins == 0 and _save.unlocked_levels == [&"level_1"], "progress cleared")
	_check(_save.player_name == "Keep" and _save.music_volume == 0.5, "name and volume kept")
	_save.load_game()
	_check(_save.best_score.is_empty() and _save.player_name == "Keep", "reset was saved")
