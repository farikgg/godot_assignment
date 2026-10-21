extends SceneTree
## Assignment 6 checks: Health, Hazard hierarchy, Spawner limit, Slash lifetime,
## the CharacterBody3D hero, roster fallback and profile migration.
## Run: godot --headless --path . -s tools/test_a6.gd   (exit code 0 = all PASS, 1 = any FAIL)

const HAZARD_SCENES: Dictionary = {
	"Rock": "res://scenes/hazards/rock.tscn",
	"BombHazard": "res://scenes/hazards/bomb.tscn",
	"Potion": "res://scenes/hazards/potion.tscn",
}
const SPAWNER_SCRIPT: String = "res://scripts/spawner.gd"
const SLASH_SCENE: String = "res://scenes/weapons/slash.tscn"
const PLAYER_SCENE: String = "res://scenes/player.tscn"
const SCRATCH_PROFILE: String = "user://test_a6_profile.cfg"
const SWORD_SCENE: String = "res://scenes/weapons/sword.tscn"
const WATCHDOG_SECONDS: float = 45.0

class WeaponTarget extends StaticBody3D:
	var hits: int = 0
	func hit_by_weapon(_damage: int = 1) -> void:
		hits += 1

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
	await _test_health()
	_test_hazard_classes()
	await _test_spawner()
	await _test_slash()
	await _test_player()
	await _test_potion_pickup()
	_test_roster_fallback()
	_test_profile_migration()
	var code: int = 1 if _failures > 0 else 0
	print("RESULT: %s, %d failure(s), exit code %d" % ["PASS" if code == 0 else "FAIL", _failures, code])
	quit(code)

func _test_health() -> void:
	var holder := Node3D.new()
	var mesh := Node3D.new()
	mesh.name = "Mesh"
	holder.add_child(mesh)
	var health := Health.new()
	health.max_hp = 3
	health.invincible_time = 0.3
	health.blink_interval = 0.05
	health.blink_target = NodePath("../Mesh")
	holder.add_child(health)
	root.add_child(holder)

	var changes: Array[int] = []
	var deaths: Array[int] = [0]
	health.changed.connect(func(current: int, _max_hp: int) -> void: changes.append(current))
	health.died.connect(func() -> void: deaths[0] += 1)

	_check("Health starts at max_hp", health.current == 3, "current=%d" % health.current)
	health.take_damage(1)
	_check("take_damage lowers HP and emits changed", health.current == 2 and changes == [2], "current=%d changes=%s" % [health.current, changes])
	health.take_damage(1)
	_check("damage ignored while invincible", health.current == 2 and health.is_invincible(), "current=%d" % health.current)
	health.heal(5)
	_check("heal is capped at max_hp", health.current == 3, "current=%d" % health.current)

	var toggled: bool = false
	for i in 4:
		await create_timer(0.05).timeout
		if not mesh.visible:
			toggled = true
	await create_timer(0.4).timeout
	_check("invincibility blinks the target and ends visible", toggled and mesh.visible and not health.is_invincible(),
		"toggled=%s visible=%s invincible=%s" % [toggled, mesh.visible, health.is_invincible()])

	health.take_damage(5)
	_check("died emitted once at 0 HP", deaths[0] == 1 and health.current == 0 and health.is_dead(), "deaths=%d current=%d" % [deaths[0], health.current])
	health.heal(1)
	health.take_damage(1)
	_check("no heal or damage after death", health.current == 0 and deaths[0] == 1, "current=%d deaths=%d" % [health.current, deaths[0]])
	holder.queue_free()

func _test_hazard_classes() -> void:
	for class_label: String in HAZARD_SCENES:
		var scene: PackedScene = load(HAZARD_SCENES[class_label]) as PackedScene
		if scene == null:
			_check("%s scene loads" % class_label, false, HAZARD_SCENES[class_label])
			continue
		var node: Node = scene.instantiate()
		var script: Script = node.get_script() as Script
		var name_ok: bool = script != null and script.get_global_name() == StringName(class_label)
		_check("%s is a Hazard" % class_label, node is Hazard and name_ok,
			"is Hazard=%s class=%s" % [node is Hazard, script.get_global_name() if script != null else "none"])
		node.free()

func _test_spawner() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var spawner := Node3D.new()
	spawner.set_script(load(SPAWNER_SCRIPT))
	spawner.set("hazard_scenes", [load(HAZARD_SCENES["Rock"]) as PackedScene] as Array[PackedScene])
	spawner.set("spawn_weights", [1.0] as Array[float])
	spawner.set("max_alive", 3)
	spawner.set("interval", 100.0)
	spawner.set("telegraph_time", 0.2)
	spawner.set("rumble_sound_path", "")
	world.add_child(spawner)
	await process_frame
	var started: int = 0
	for i in 10:
		if spawner.call("spawn_one"):
			started += 1
	var pending: int = spawner.call("alive_count")
	await create_timer(0.4).timeout
	var alive: int = get_nodes_in_group("hazard").size()
	_check("spawner respects max_alive (telegraphed drops count)", started == 3 and pending == 3 and alive == 3,
		"started=%d pending=%d alive=%d (max 3)" % [started, pending, alive])
	world.queue_free()
	await process_frame
	await _test_spawn_weights()

func _make_spawner(world: Node3D, scenes: Array[PackedScene], weights: Array[float]) -> Node3D:
	var spawner := Node3D.new()
	spawner.set_script(load(SPAWNER_SCRIPT))
	spawner.set("hazard_scenes", scenes)
	spawner.set("spawn_weights", weights)
	spawner.set("max_alive", 50)
	spawner.set("interval", 100.0)
	spawner.set("telegraph_time", 0.05)
	spawner.set("rumble_sound_path", "")
	world.add_child(spawner)
	return spawner

func _test_spawn_weights() -> void:
	var scenes: Array[PackedScene] = [
		load(HAZARD_SCENES["BombHazard"]) as PackedScene,
		load(HAZARD_SCENES["Rock"]) as PackedScene,
		load(HAZARD_SCENES["Potion"]) as PackedScene,
	]
	var world := Node3D.new()
	root.add_child(world)
	var spawner: Node3D = _make_spawner(world, scenes, [1.0, 0.0, 0.0] as Array[float])
	await process_frame
	for i in 12:
		spawner.call("spawn_one")
	await create_timer(0.3).timeout
	var kinds: Dictionary = {}
	for hazard in get_nodes_in_group("hazard"):
		kinds[(hazard.get_script() as Script).get_global_name()] = true
	_check("weights 1/0/0 spawn only powder kegs", kinds.keys() == [&"BombHazard"], "spawned kinds=%s" % [kinds.keys()])
	world.queue_free()
	await process_frame

	# a broken table is reported and the spawner stays idle (the ERROR line below is expected)
	print("  (expected ERROR: 2 weights for 3 scenes)")
	var broken_world := Node3D.new()
	root.add_child(broken_world)
	var broken: Node3D = _make_spawner(broken_world, scenes, [1.0, 0.0] as Array[float])
	await process_frame
	var started: bool = broken.call("spawn_one")
	_check("mismatched weights stop the spawner without crashing", not broken.call("is_valid") and not started,
		"valid=%s spawn_one=%s" % [broken.call("is_valid"), started])
	broken_world.queue_free()
	await process_frame

func _test_slash() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var target := WeaponTarget.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	target.add_child(shape)
	world.add_child(target)
	await physics_frame
	# the target is already inside when the slash appears
	var slash: Slash = (load(SLASH_SCENE) as PackedScene).instantiate() as Slash
	world.add_child(slash)
	for i in 6:
		await physics_frame
	_check("slash hits a body already inside exactly once", target.hits == 1, "hits=%d" % target.hits)
	await create_timer(0.3).timeout
	_check("slash frees itself after its lifetime", not is_instance_valid(slash), "lifetime=0.15 s")
	world.queue_free()

func _test_player() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.1
	world.add_child(floor_body)
	var player: Node = (load(PLAYER_SCENE) as PackedScene).instantiate()
	world.add_child(player)
	var body: CharacterBody3D = player as CharacterBody3D
	var health: Health = player.get_node_or_null("Health") as Health
	_check("player is a CharacterBody3D in group player with Health and Hurtbox",
		body != null and player.is_in_group("player") and health != null and player.get_node_or_null("Hurtbox") is Area3D,
		"class=%s" % player.get_class())
	if body == null or health == null:
		world.queue_free()
		return
	var visual: Node = player.get_node("Visual")
	_check("Visual holds the roster model", visual.get_child_count() > 0, "children=%d" % visual.get_child_count())
	for i in 10:
		await physics_frame
	_check("player stands on the floor", body.is_on_floor(), "y=%.2f" % body.global_position.y)

	_check("player starts without a weapon", not player.call("has_weapon"), "")
	_press("attack")
	for i in 3:
		await physics_frame
	_check("attack before the pickup creates no Slash", _count_slashes(world) == 0, "slashes=%d" % _count_slashes(world))
	player.call("equip_weapon", load(SWORD_SCENE) as PackedScene)
	await process_frame
	await process_frame
	_press("attack")
	for i in 3:
		await physics_frame
	_check("attack after equip_weapon creates a Slash", player.call("has_weapon") and _count_slashes(world) == 1,
		"has_weapon=%s slashes=%d" % [player.call("has_weapon"), _count_slashes(world)])

	# an enemy touching the hurtbox costs 1 HP and pushes the player away
	var enemy := StaticBody3D.new()
	enemy.add_to_group("enemy")
	var enemy_shape := CollisionShape3D.new()
	enemy_shape.shape = SphereShape3D.new()
	enemy.add_child(enemy_shape)
	world.add_child(enemy)
	enemy.global_position = body.global_position + Vector3(0.7, 0.6, 0)
	for i in 4:
		await physics_frame
	_check("enemy contact damages and knocks back", health.current == health.max_hp - 1 and body.velocity.x < 0.0,
		"hp=%d vel.x=%.2f" % [health.current, body.velocity.x])
	enemy.queue_free()

	# hazards still find the CharacterBody3D through body_entered
	await create_timer(health.invincible_time + 0.2).timeout
	var rock: Hazard = (load(HAZARD_SCENES["Rock"]) as PackedScene).instantiate() as Hazard
	world.add_child(rock)
	rock.global_position = body.global_position + Vector3(0, 2.5, 0)
	for i in 60:
		await physics_frame
	_check("a rock hits the CharacterBody3D player", health.current == health.max_hp - 2, "hp=%d" % health.current)
	current_scene = null
	world.queue_free()
	await process_frame

# hero at full HP walks into the potion: it stays; hero at 2 HP: healed to 3, potion gone
func _check_potion(label: String, potion: Node3D, hero: CharacterBody3D, health: Health) -> void:
	var spot: Vector3 = potion.global_position
	hero.global_position = spot + Vector3(3.0, 0.0, 0.0)
	await _physics_frames(5)
	hero.global_position = Vector3(spot.x, hero.global_position.y, spot.z)
	await _physics_frames(5)
	_check("%s: full HP leaves the potion lying" % label, is_instance_valid(potion) and health.current == health.max_hp,
		"hp %d, potion %s" % [health.current, is_instance_valid(potion)])
	hero.global_position = spot + Vector3(3.0, 0.0, 0.0)
	await _physics_frames(5)
	health.take_damage(1)
	# the hero's first visit may have nudged the rigid body; walk into where it lies now
	spot = potion.global_position
	hero.global_position = Vector3(spot.x, hero.global_position.y, spot.z)
	await _physics_frames(5)
	_check("%s: 2 HP -> 3 HP, potion removed" % label, health.current == health.max_hp and not is_instance_valid(potion),
		"hp %d, potion %s" % [health.current, is_instance_valid(potion)])

func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame

func _test_potion_pickup() -> void:
	var map: Node3D = (load("res://scenes/levels/level_1.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(map)
	current_scene = map
	var hero: CharacterBody3D = map.get_node("Player") as CharacterBody3D
	var health: Health = hero.get_node("Health") as Health
	await _physics_frames(5)
	await _check_potion("lying potion", map.get_node("PotionPickup") as Node3D, hero, health)
	# a cave-in potion: dropped on the floor, freezes on landing
	var dropped: Potion = (load(HAZARD_SCENES["Potion"]) as PackedScene).instantiate() as Potion
	map.add_child(dropped)
	dropped.global_position = Vector3(-6.0, 1.5, 6.0)
	await create_timer(1.5, false).timeout
	await create_timer(health.invincible_time, false).timeout
	_check("dropped potion lies frozen on the floor", is_instance_valid(dropped) and dropped.freeze,
		"freeze %s" % (dropped.freeze if is_instance_valid(dropped) else "freed"))
	if is_instance_valid(dropped):
		await _check_potion("dropped potion", dropped, hero, health)
	current_scene = null
	map.queue_free()
	await process_frame

func _test_roster_fallback() -> void:
	var roster: Node = root.get_node_or_null("Roster")
	if roster == null:
		_check("Roster autoload present", false)
		return
	var first: CharacterData = roster.call("first")
	var fallback: CharacterData = roster.call("get_by_id", &"no_such_hero")
	_check("Roster.get_by_id falls back to the first hero", first != null and fallback == first,
		"first=%s fallback=%s" % [first.id if first else "none", fallback.id if fallback else "none"])

func _test_profile_migration() -> void:
	var profile: Node = root.get_node_or_null("Profile")
	var roster: Node = root.get_node_or_null("Roster")
	if profile == null or roster == null:
		_check("Profile and Roster autoloads present", false)
		return
	var original_path: String = profile.get("save_path")
	var old := ConfigFile.new()
	old.set_value("profile", "player_name", "Old Hero")
	old.set_value("profile", "ball_color_index", 2)
	old.save(SCRATCH_PROFILE)
	profile.set("save_path", SCRATCH_PROFILE)
	profile.call("reload")
	var first_id: StringName = (roster.call("first") as CharacterData).id
	var migrated := ConfigFile.new()
	migrated.load(SCRATCH_PROFILE)
	_check("Profile migrates the old ball colour save to the first hero",
		profile.get("character_id") == first_id and profile.get("player_name") == "Old Hero"
			and migrated.get_value("profile", "character_id", "") == String(first_id)
			and not migrated.has_section_key("profile", "ball_color_index"),
		"character_id=%s name=%s" % [profile.get("character_id"), profile.get("player_name")])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_PROFILE))
	profile.set("save_path", original_path)
	profile.call("reload")

func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)

func _count_slashes(parent: Node) -> int:
	var count: int = 0
	for child in parent.get_children():
		if child is Slash:
			count += 1
	return count
