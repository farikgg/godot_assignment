extends SceneTree
## Headless check that the balance lives in the data assets and reaches the game:
##   Godot --headless --path . -s res://tests/test_balance_data.gd
## Every data .tres validates; in the real levels the hero, enemies, HUD and coins use its numbers.
## Prints MEASURE lines (hero speed, boss HP) used to prove a .tres edit changes the game.

const DATA_DIRS: Array[String] = ["res://resources/enemies", "res://resources/hazards",
	"res://resources/pickups", "res://resources/spawners"]
const PLAYER_DATA: String = "res://resources/player.tres"
## Physics frames the hero runs right before the speed is read (accelerates to full speed).
const RUN_FRAMES: int = 60
const SETTLE_FRAMES: int = 10
## Spawned enemies settle onto the floor and patrollers start walking during the settle frames.
const MARKER_TOLERANCE: float = 1.0
const WAKE_MARGIN_SEC: float = 0.5
const PATROL_WAIT_SEC: float = 2.0
const PATROL_MIN_MOVE: float = 0.5

var _failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	root.get_node("SaveGame").save_path = "user://test_balance_save.json"
	_check_assets()
	await _check_level("res://scenes/levels/level_1.tscn")
	await _check_level("res://scenes/levels/level_2.tscn")
	await _check_level("res://scenes/levels/level_3_boss.tscn")
	print("Balance data tests: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	root.get_node("MusicPlayer").stop_all()
	root.get_node("GameFlow").stop_all_sounds()
	await create_timer(0.2).timeout
	DirAccess.remove_absolute("user://test_balance_save.json")
	quit(1 if _failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)

func _check_assets() -> void:
	print("data assets validate")
	var paths: Array[String] = [PLAYER_DATA]
	for dir in DATA_DIRS:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".tres"):
				paths.append(dir.path_join(file))
	for path in paths:
		var resource: Resource = load(path)
		var problems: PackedStringArray = resource.call("validate") if resource != null and resource.has_method("validate") else PackedStringArray()
		_check(resource != null and problems.is_empty(), "%s %s" % [path, ", ".join(problems)])

func _check_level(path: String) -> void:
	print(path)
	change_scene_to_file(path)
	for i in SETTLE_FRAMES:
		await physics_frame
	var level: Node = current_scene
	var player: Node = level.get_tree().get_first_node_in_group("player")
	var data: PlayerData = player.get("data")
	var health: Health = player.get_node("Health")
	_check(health.max_hp == data.max_hp and health.current == data.max_hp, "hero HP = PlayerData.max_hp (%d)" % data.max_hp)
	_check(level.get_node("HUD/%HeartsBox").get_child_count() == data.max_hp, "HUD hearts = max_hp")
	var gold: int = 0
	for coin in level.get_tree().get_nodes_in_group("coins"):
		gold += coin.call("get_value")
	_check(level.get("coins_total") == gold, "coins_total = sum of PickupData values (%d)" % gold)
	for enemy in level.get_tree().get_nodes_in_group("enemy"):
		if enemy is Enemy:
			var e: Enemy = enemy
			_check(e.is_configured() and e.health.max_hp == e.data.max_hp,
				"%s configured, HP %d from %s" % [e.name, e.data.max_hp, e.data.resource_path.get_file()])
	var level_data: LevelData = level.get("data")
	var spawned: int = 0
	for enemy in level.get_tree().get_nodes_in_group("enemy"):
		if enemy is Enemy:
			spawned += 1
	_check(level_data != null and spawned == level_data.enemy_spawns.size(),
		"%d AI enemies spawned from LevelData" % spawned)
	var spawners: int = 0
	for child in level.get_children():
		if child.get(&"data") is SpawnerData:
			spawners += 1
	_check(spawners == (1 if level_data.spawner != null else 0), "cave-in from LevelData: %d" % spawners)
	for spawn in level_data.enemy_spawns:
		var marker: Node3D = level.find_children(String(spawn.marker), "Marker3D", true, false)[0]
		var near: bool = false
		for enemy in level.get_tree().get_nodes_in_group("enemy"):
			if enemy is Enemy and (enemy as Node3D).global_position.distance_to(marker.global_position) < MARKER_TOLERANCE:
				near = true
		_check(near, "an enemy stands on %s" % spawn.marker)
	for boss in level.get_tree().get_nodes_in_group("boss"):
		print("MEASURE boss_max_hp=%d" % (boss as Boss).health.max_hp)
		await create_timer((boss as Boss).stats.wake_delay + WAKE_MARGIN_SEC).timeout
		_check((boss as Boss).is_awake(), "spawned boss wakes up and fights")
	if path.ends_with("level_1.tscn"):
		var minion: Node3D = null
		for enemy in level.get_tree().get_nodes_in_group("enemy"):
			if enemy is Minion:
				minion = enemy
		var start: Vector3 = minion.global_position
		await create_timer(PATROL_WAIT_SEC).timeout
		_check(minion.global_position.distance_to(start) > PATROL_MIN_MOVE, "spawned Minion patrols (moved %.2f m)" % minion.global_position.distance_to(start))
	if path.ends_with("level_1.tscn"):
		# hold "right" and measure the speed the hero actually reaches
		# PlayerInputHandler reads input events, so press the action as an event
		_send_action(&"move_right", true)
		# the peak: a wall ahead may stop the hero before the frames run out
		var speed: float = 0.0
		for i in RUN_FRAMES:
			await physics_frame
			var velocity: Vector3 = (player as CharacterBody3D).velocity
			speed = maxf(speed, Vector2(velocity.x, velocity.z).length())
		print("MEASURE hero_speed=%.2f" % speed)
		_send_action(&"move_right", false)
		_check(is_equal_approx(snappedf(speed, 0.01), data.move_speed), "hero runs at PlayerData.move_speed")

func _send_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
