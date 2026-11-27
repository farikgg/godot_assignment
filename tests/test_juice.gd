extends SceneTree
## Headless check of the juice infrastructure. Run from the project folder:
##   Godot --headless --path . -s res://tests/test_juice.gd
## HitStop: every restore path, overlapping requests, clamping, refusals, the hero-death block, a
## mutation of GameFlow._change_scene without its restore (the scene-change check must catch it),
## the quit path last (it ends the run). GameEvents: every gameplay emit on level_1.
## Autoloads are reached through root.get_node (a -s script compiles before they exist).
## Uses user://test_juice_save.json; quit_game writes it once more at the very end.

const TEST_SAVE: String = "user://test_juice_save.json"
const GAME_FLOW_PATH: String = "res://scripts/game_flow.gd"
const HIT_STOP_PATH: String = "res://scripts/autoload/hit_stop.gd"
const RESTORE_LINE: String = "\tHitStop.restore()\n"
const SCRIPTS_DIR: String = "res://scripts"
const TIME_SCALE_WRITE: String = "Engine.time_scale ="
const MENU_SCENE: String = "res://scenes/main_menu.tscn"
const SETTLE_FRAMES: int = 6
## Real seconds; a stop of SHORT_SEC must be over after SHORT_SEC + MARGIN_SEC.
const SHORT_SEC: float = 0.05
const MARGIN_SEC: float = 0.1
const USEC_PER_SEC: float = 1000000.0
const LONG_REQUEST_SEC: float = 10.0
const DROP_HEIGHT: float = 2.0
const LANDING_FRAMES: int = 120
## Level.EXIT_DELAY / RESTART_DELAY plus a margin.
const RESULT_WAIT_SEC: float = 2.5

var _failures: int = 0
var _flow: Node
var _save: Node
var _hit_stop: Node
var _events: Node
var _juice: JuiceData
var _counts: Dictionary[StringName, int] = {}
var _last_kill: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_flow = root.get_node("GameFlow")
	_save = root.get_node("SaveGame")
	_hit_stop = root.get_node("HitStop")
	_events = root.get_node("GameEvents")
	_save.save_path = TEST_SAVE
	_cleanup()
	_save.load_game()
	_juice = JuiceData.get_data()

	_test_data()
	_test_single_owner()
	await _test_requests()
	await _test_restore_paths()
	await _test_mutation()
	await _test_emits()
	await _test_quit()

func _test_data() -> void:
	print("juice.tres")
	_check(_juice.validate().is_empty(), "juice.tres has no problems")
	_check(is_equal_approx(_juice.hit_stop_enemy_kill_sec, SHORT_SEC) and is_equal_approx(_juice.hit_stop_boss_hit_sec, SHORT_SEC) \
		and is_equal_approx(_juice.hit_stop_hero_hurt_sec, SHORT_SEC), "hit stops are 0.05 s")
	var broken := JuiceData.new()
	_check(not broken.validate().is_empty() and not broken.hit_stop_ok(), "an empty JuiceData reports problems")

func _test_single_owner() -> void:
	print("HitStop is the only writer of Engine.time_scale")
	var writers: Array[String] = []
	for path in _gd_files(SCRIPTS_DIR):
		if FileAccess.get_file_as_string(path).contains(TIME_SCALE_WRITE):
			writers.append(path)
	_check(writers == [HIT_STOP_PATH], "writers: %s" % [writers])

func _test_requests() -> void:
	print("requests")
	_check(Engine.time_scale == 1.0 and not _hit_stop.is_active(), "starts at exactly 1.0")
	_check(_hit_stop.request(SHORT_SEC), "request accepted")
	_check(is_equal_approx(Engine.time_scale, _juice.hit_stop_time_scale), "slowed to hit_stop_time_scale")
	await _real_wait(SHORT_SEC + MARGIN_SEC)
	_check(Engine.time_scale == 1.0 and not _hit_stop.is_active(), "ends by itself in real time, exactly 1.0")

	_hit_stop.request(SHORT_SEC)
	_hit_stop.request(_juice.hit_stop_max_sec)
	_check(_hit_stop.remaining_sec() > SHORT_SEC, "short then long: the longer end wins")
	_hit_stop.restore()
	_hit_stop.request(_juice.hit_stop_max_sec)
	_hit_stop.request(SHORT_SEC * 0.5)
	_check(_hit_stop.remaining_sec() > SHORT_SEC, "long then short: the end is not shortened")
	await _real_wait(SHORT_SEC + MARGIN_SEC * 0.2)
	_check(_hit_stop.is_active(), "overlap: still active after the short one's end")
	await _real_wait(_juice.hit_stop_max_sec + MARGIN_SEC)
	_check(Engine.time_scale == 1.0, "overlap: restored after the long one's end")

	_hit_stop.request(LONG_REQUEST_SEC)
	_check(_hit_stop.remaining_sec() <= _juice.hit_stop_max_sec, "a long request is clamped to hit_stop_max_sec")
	_hit_stop.restore()
	_check(not _hit_stop.request(0.0) and not _hit_stop.request(-1.0), "zero or negative refused")
	paused = true
	_check(not _hit_stop.request(SHORT_SEC) and Engine.time_scale == 1.0, "refused while paused")
	paused = false

func _test_restore_paths() -> void:
	print("restore paths")
	await _load_level_1()
	var pause_menu: Node = current_scene.find_child("PauseMenu", true, false)
	_check(pause_menu != null, "level_1 has a pause menu")
	if pause_menu != null:
		_hit_stop.request(_juice.hit_stop_max_sec)
		pause_menu.call("set_paused", true)
		_check(Engine.time_scale == 1.0, "pause menu opened -> 1.0 at once")
		pause_menu.call("set_paused", false)

	_hit_stop.request(_juice.hit_stop_max_sec)
	paused = true
	await process_frame
	_check(Engine.time_scale == 1.0, "tree paused by anyone -> 1.0 on the next frame")
	paused = false

	for what in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT,
			Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_hit_stop.request(_juice.hit_stop_max_sec)
		_hit_stop.notification(what)
		_check(Engine.time_scale == 1.0, "notification %d -> 1.0" % what)

	_hit_stop.request(_juice.hit_stop_max_sec)
	root.remove_child(_hit_stop)
	_check(Engine.time_scale == 1.0, "HitStop leaving the tree -> 1.0")
	root.add_child(_hit_stop)

	_hit_stop.request(_juice.hit_stop_max_sec)
	_events.hero_died.emit(Vector3.ZERO)
	_check(Engine.time_scale == 1.0, "hero death -> 1.0")
	_check(not _hit_stop.request(SHORT_SEC), "no new stop in the scene where the hero died")

	_check(_flow.restart_level() == OK, "restart_level")
	_check(Engine.time_scale == 1.0, "restart -> 1.0")
	await _settle()
	_check(_hit_stop.request(SHORT_SEC), "a new scene accepts stops again")
	_check(_flow.restart_level() == OK and Engine.time_scale == 1.0, "restart during a stop -> 1.0 at once")
	await _settle()
	_hit_stop.request(_juice.hit_stop_max_sec)
	_flow.go_to_menu()
	_check(Engine.time_scale == 1.0, "menu during a stop -> 1.0 at once")
	await _settle()
	await _load_level_1()
	_hit_stop.request(_juice.hit_stop_max_sec)
	_flow.go_to_win(0)
	_check(Engine.time_scale == 1.0, "win screen during a stop -> 1.0 at once")
	await _settle()

	# a scene change that skips GameFlow is caught by the per-frame scene check
	_hit_stop.request(_juice.hit_stop_max_sec)
	change_scene_to_file(MENU_SCENE)
	await _settle()
	_check(Engine.time_scale == 1.0, "change_scene_to_file outside GameFlow -> 1.0 within frames")

# GameFlow._change_scene without its HitStop.restore() must fail the check used above
func _test_mutation() -> void:
	print("mutation: _change_scene without HitStop.restore()")
	var source: String = FileAccess.get_file_as_string(GAME_FLOW_PATH)
	var body_start: int = source.find("func _change_scene(")
	var line_at: int = source.find(RESTORE_LINE, body_start)
	_check(body_start != -1 and line_at != -1, "the restore line is inside _change_scene")
	if body_start == -1 or line_at == -1:
		return
	var mutated := GDScript.new()
	mutated.source_code = source.substr(0, line_at) + source.substr(line_at + RESTORE_LINE.length())
	_check(mutated.reload() == OK, "mutated GameFlow compiles")
	var mutant: Node = mutated.new() as Node
	root.add_child(mutant)
	_hit_stop.request(_juice.hit_stop_max_sec)
	mutant.call("_change_scene", MENU_SCENE)
	_check(Engine.time_scale != 1.0, "mutant: still slowed right after the scene change (the check would fail)")
	mutant.queue_free()
	_hit_stop.restore()
	await _settle()

func _test_emits() -> void:
	print("GameEvents emits on level_1")
	# signal -> number of its arguments, dropped by unbind so _count only gets the name
	var arg_counts: Dictionary[StringName, int] = {
		&"enemy_hit": 3, &"enemy_died": 2, &"hero_hurt": 2, &"hero_died": 1, &"hero_landed": 2,
		&"pickup_collected": 2, &"level_won": 1, &"level_lost": 1,
	}
	for signal_name in arg_counts:
		_counts[signal_name] = 0
		_events.connect(signal_name, _count.bind(signal_name).unbind(arg_counts[signal_name]))
	_events.enemy_hit.connect(func(_p: Vector3, _e: Node3D, killed: bool) -> void: _last_kill = killed)
	await _load_level_1()
	var hero: Node3D = get_first_node_in_group("player") as Node3D
	_check(hero != null, "hero present")
	if hero == null:
		return

	hero.global_position += Vector3.UP * DROP_HEIGHT
	_counts[&"hero_landed"] = 0
	for i in LANDING_FRAMES:
		await physics_frame
		if _counts[&"hero_landed"] > 0:
			break
	_check(_counts[&"hero_landed"] == 1, "hero_landed after a drop")

	var coin: Node = get_first_node_in_group("coins")
	if coin != null:
		coin.call("_on_body_entered", hero)
	_check(_counts[&"pickup_collected"] == 1, "pickup_collected for a coin")

	# untyped: Enemy uses autoload names, which a -s script cannot compile against
	var enemy: Node3D = _first_live_enemy()
	_check(enemy != null, "an enemy on level_1")
	if enemy != null:
		enemy.call("hit_by_weapon", (enemy.get_node("Health") as Health).current)
		_check(_counts[&"enemy_hit"] == 1 and _last_kill, "enemy_hit with killed = true")
		_check(_counts[&"enemy_died"] == 1, "enemy_died once")

	var health: Health = hero.get_node("Health") as Health
	health.take_damage(1)
	_check(_counts[&"hero_hurt"] == 1, "hero_hurt")
	current_scene.set("coins_collected", 9999)
	current_scene.call("_on_exit_reached")
	_check(_counts[&"level_won"] == 1, "level_won at the exit")
	# let the level finish its own move to the next scene before replacing it
	await _real_wait(RESULT_WAIT_SEC)
	await _load_level_1()
	(get_first_node_in_group("player").get_node("Health") as Health).kill()
	_check(_counts[&"hero_died"] == 1 and _counts[&"level_lost"] == 1, "hero_died and level_lost")
	await _real_wait(RESULT_WAIT_SEC)
	_flow.go_to_menu()
	await _settle()

func _test_quit() -> void:
	print("quit_game (last: it ends the run)")
	var code: int = 1 if _failures > 0 else 0
	_hit_stop.request(_juice.hit_stop_max_sec)
	_flow.quit_game(code)
	var ok: bool = Engine.time_scale == 1.0
	_check(ok, "quit_game -> 1.0 at once")
	print("Juice tests: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	if not ok:
		# ends the main loop before GameFlow's own quit(code) can report success
		quit(1)

func _count(signal_name: StringName) -> void:
	_counts[signal_name] += 1

func _load_level_1() -> void:
	_check(_flow.start_level(0) == OK, "start level_1")
	await _settle()

func _settle() -> void:
	for i in SETTLE_FRAMES:
		await process_frame

# wall-clock seconds, like HitStop: a SceneTreeTimer counts frame delta, which right after start-up
# can jump far ahead of real time; plus one frame, since a stop ends on HitStop's next _process
func _real_wait(seconds: float) -> void:
	var end_usec: int = Time.get_ticks_usec() + int(seconds * USEC_PER_SEC)
	while Time.get_ticks_usec() < end_usec:
		await process_frame
	await process_frame

# group "enemy" also holds static props (scenes/props/enemy.tscn): take one with Health
func _first_live_enemy() -> Node3D:
	for node in get_nodes_in_group("enemy"):
		if node.has_method("hit_by_weapon") and node.get_node_or_null("Health") is Health:
			return node as Node3D
	return null

func _gd_files(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		_check(false, "cannot open %s" % dir_path)
		return found
	for file in dir.get_files():
		if file.get_extension() == "gd":
			found.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		found.append_array(_gd_files(dir_path.path_join(sub)))
	return found

func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)

func _cleanup() -> void:
	for path in [TEST_SAVE, TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
