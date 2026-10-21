extends SceneTree
## Midterm stage 2A checks: Slash vs boss and minion, boss death and phase 2, projectile lifetime and
## the fire rain warning, minion sight and ledges, pause-aware timers, class hierarchy.
## Run: godot --headless --path . -s tools/test_enemies.gd   (exit code 0 = all PASS, 1 = any FAIL)

const WATCHDOG_SECONDS: float = 60.0
const SLASH_SCENE: String = "res://scenes/weapons/slash.tscn"
const BOSS_SCENE: String = "res://scenes/enemies/boss.tscn"
const MINION_SCENE: String = "res://scenes/enemies/minion.tscn"
const FIREBALL_SCENE: String = "res://scenes/projectiles/fireball.tscn"
const RAIN_SCENE: String = "res://scenes/projectiles/fire_rain_drop.tscn"
const SLAB_SCENE: String = "res://scenes/props/floor_slab.tscn"
const SKELETON_DATA: String = "res://resources/enemies/skeleton.tres"
## Boss invincibility is 0.4 s; wait a little longer between hits.
const HIT_GAP: float = 0.45

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

func _settle() -> void:
	for i in 3:
		await process_frame

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _run() -> void:
	_test_classes()
	await _test_minion_slash()
	await _test_fireball_lifetime()
	await _test_rain_warning()
	await _test_minion_sight()
	await _test_minion_ledge()
	await _test_boss_pause()
	await _test_boss_fight()
	var code: int = 1 if _failures > 0 else 0
	print("RESULT: %s, %d failure(s), exit code %d" % ["PASS" if code == 0 else "FAIL", _failures, code])
	# stops the music and sounds first, so nothing leaks at exit
	root.get_node("GameFlow").call("quit_game", code)

func _test_classes() -> void:
	for pair in [[BOSS_SCENE, "Boss"], [MINION_SCENE, "Minion"]]:
		var node: Node = (load(pair[0]) as PackedScene).instantiate()
		_check("%s is an Enemy" % pair[1], node is Enemy, node.get_class())
		node.free()
	for pair in [[FIREBALL_SCENE, "Fireball"], [RAIN_SCENE, "FireRainDrop"]]:
		var node: Node = (load(pair[0]) as PackedScene).instantiate()
		_check("%s is a Projectile" % pair[1], node is Projectile, node.get_class())
		node.free()

## Opens a level through GameFlow (index 0..2) and returns the scene once it is current.
func _open_level(index: int) -> Node:
	var flow: Node = _flow()
	flow.start_game()
	await _settle()
	for i in index:
		flow.next_level()
		await _settle()
	return current_scene

func _slash_at(target: Node3D) -> void:
	var slash: Slash = (load(SLASH_SCENE) as PackedScene).instantiate() as Slash
	current_scene.add_child(slash)
	slash.global_position = target.global_position + Vector3.UP * 0.6
	await _frames(3)

func _test_minion_slash() -> void:
	var level: Node = await _open_level(0)
	var minion: Minion = level.get_node("Enemies/Skeleton") as Minion
	var before: int = minion.health.current
	await _slash_at(minion)
	_check("Slash lowers minion HP", minion.health.current == before - 1, "%d -> %d" % [before, minion.health.current])

# a bare scene: floor slabs and a stand-in hero with Health in group "player". The previous level
# goes first, or its hero would be the one enemies target (and its death would restart a level).
func _sandbox(slabs: Array[Rect2]) -> Node3D:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await _settle()
	var world := Node3D.new()
	world.name = "Sandbox"
	root.add_child(world)
	current_scene = world
	for rect in slabs:
		var slab: FloorSlab = (load(SLAB_SCENE) as PackedScene).instantiate() as FloorSlab
		world.add_child(slab)
		slab.size = rect.size
		slab.position = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	return world

func _make_hero(world: Node3D, at: Vector3) -> CharacterBody3D:
	var hero := CharacterBody3D.new()
	hero.name = "Hero"
	hero.add_to_group("player")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.1
	shape.shape = capsule
	shape.position.y = 0.55
	hero.add_child(shape)
	var health := Health.new()
	health.name = "Health"
	health.max_hp = 3
	hero.add_child(health)
	world.add_child(hero)
	hero.global_position = at
	return hero

func _make_minion(world: Node3D, at: Vector3, offset: Vector3) -> Minion:
	var minion: Minion = (load(MINION_SCENE) as PackedScene).instantiate() as Minion
	minion.data = load(SKELETON_DATA) as EnemyData
	minion.patrol_offset = offset
	minion.position = at
	world.add_child(minion)
	return minion

func _clear_sandbox(world: Node3D) -> void:
	current_scene = null
	world.queue_free()
	await _settle()

func _test_fireball_lifetime() -> void:
	var world: Node3D = await _sandbox([])
	var ball: Projectile = (load(FIREBALL_SCENE) as PackedScene).instantiate() as Projectile
	world.add_child(ball)
	ball.launch(Vector3(0.0, 50.0, 0.0), Vector3.FORWARD)
	var lifetime: float = ball.lifetime
	await create_timer(lifetime * 0.5, false).timeout
	_check("Fireball alive halfway through its lifetime", is_instance_valid(ball))
	await create_timer(lifetime * 0.5 + 0.2, false).timeout
	_check("Fireball freed after its lifetime", not is_instance_valid(ball), "lifetime %.1f s" % lifetime)
	await _clear_sandbox(world)

func _test_rain_warning() -> void:
	var world: Node3D = await _sandbox([Rect2(-4.0, -4.0, 8.0, 8.0)])
	var hero: CharacterBody3D = _make_hero(world, Vector3.ZERO)
	var health: Health = hero.get_node("Health") as Health
	await _frames(2)
	var drop: FireRainDrop = (load(RAIN_SCENE) as PackedScene).instantiate() as FireRainDrop
	world.add_child(drop)
	drop.drop_at(Vector3.ZERO)
	await create_timer(drop.warning_time - 0.1, false).timeout
	_check("FireRainDrop harmless during the warning", health.current == health.max_hp and not drop.is_falling(),
		"hp %d, falling %s" % [health.current, drop.is_falling()])
	await create_timer(0.8, false).timeout
	_check("FireRainDrop hurts after the warning", health.current < health.max_hp, "hp %d" % health.current)
	await _clear_sandbox(world)

func _test_minion_sight() -> void:
	var world: Node3D = await _sandbox([Rect2(-10.0, -10.0, 20.0, 20.0)])
	var minion: Minion = _make_minion(world, Vector3.ZERO, Vector3(2.0, 0.0, 0.0))
	var hero: CharacterBody3D = _make_hero(world, Vector3(0.0, 0.0, 9.0))
	await _frames(20)
	_check("Minion patrols while the hero is far", minion.state == Minion.State.PATROL, Minion.State.keys()[minion.state])
	# a wall between them: in range but not visible
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 3.0, 0.4)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	world.add_child(wall)
	wall.global_position = Vector3(minion.global_position.x, 1.5, 2.5)
	# the physics space picks the wall up on the next step; only then bring the hero in range
	await _frames(3)
	hero.global_position = Vector3(minion.global_position.x, 0.0, 4.0)
	await _frames(10)
	_check("Minion keeps patrolling when a wall hides the hero", minion.state == Minion.State.PATROL, Minion.State.keys()[minion.state])
	wall.queue_free()
	await _frames(10)
	_check("Minion chases a visible hero in sight_radius", minion.state == Minion.State.CHASE, Minion.State.keys()[minion.state])
	await _clear_sandbox(world)

func _test_minion_ledge() -> void:
	# minion island x -2..2, a 3 m pit, the hero's island x 5..9
	var world: Node3D = await _sandbox([Rect2(-2.0, -2.0, 4.0, 4.0), Rect2(5.0, -2.0, 4.0, 4.0)])
	var minion: Minion = _make_minion(world, Vector3.ZERO, Vector3(0.0, 0.0, 1.0))
	_make_hero(world, Vector3(6.0, 0.0, 0.0))
	await _frames(180)
	var position: Vector3 = minion.global_position
	_check("Minion chases towards the hero across the pit", minion.state == Minion.State.CHASE, Minion.State.keys()[minion.state])
	_check("Minion stops at the ledge instead of falling", position.y > -0.1 and position.x < 2.0,
		"at (%.2f, %.2f)" % [position.x, position.y])
	await _clear_sandbox(world)

func _test_boss_pause() -> void:
	var level: Node = await _open_level(2)
	var boss: Boss = level.get_node("BossSpawn/Boss") as Boss
	boss.awaken()
	await _frames(5)
	var timer: Timer = boss.get_node("StateTimer") as Timer
	var state: Boss.State = boss.state
	var left: float = timer.time_left
	paused = true
	await create_timer(1.5, true, false, true).timeout
	_check("Boss timer frozen on pause", is_equal_approx(timer.time_left, left) and boss.state == state,
		"%.3f -> %.3f, %s -> %s" % [left, timer.time_left, Boss.State.keys()[state], Boss.State.keys()[boss.state]])
	paused = false

func _count_fireballs() -> int:
	return current_scene.find_children("*", "Fireball", true, false).size()

func _test_boss_fight() -> void:
	var level: Node = await _open_level(2)
	var boss: Boss = level.get_node("BossSpawn/Boss") as Boss
	var hero_health: Health = level.get_node("Player/Health") as Health
	# keep the hero alive whatever the boss throws during the test (test-only use of the private flag)
	hero_health.set("_invincible", true)
	await _frames(2)
	var before: int = _count_fireballs()
	boss.fire_fan()
	var phase_one_fan: int = _count_fireballs() - before
	_check("phase 1 fan: 5 fireballs", phase_one_fan == 5, str(phase_one_fan))

	await _slash_at(boss)
	_check("Slash lowers boss HP", boss.health.current == 7, "hp %d" % boss.health.current)
	for i in 3:
		await create_timer(HIT_GAP, false).timeout
		boss.hit_by_weapon(1)
	_check("phase 2 at 50% HP", boss.is_enraged() and boss.health.current == 4, "hp %d" % boss.health.current)
	before = _count_fireballs()
	boss.fire_fan()
	var phase_two_fan: int = _count_fireballs() - before
	_check("phase 2 fan: more fireballs (7)", phase_two_fan == 7 and phase_two_fan > phase_one_fan, str(phase_two_fan))
	_check("phase 2 rain: more drops (6)", boss.current_rain_count() == 6, str(boss.current_rain_count()))

	for i in 4:
		await create_timer(HIT_GAP, false).timeout
		boss.hit_by_weapon(1)
	_check("8 hits: boss DEAD", boss.state == Boss.State.DEAD and boss.health.current == 0, Boss.State.keys()[boss.state])
	await create_timer(boss.defeat_delay + 0.3, false).timeout
	await _settle()
	var path: String = current_scene.scene_file_path if current_scene != null else "<none>"
	_check("boss defeat opens the win screen", path == _flow().WIN_SCENE, path)
