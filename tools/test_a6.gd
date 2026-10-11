extends SceneTree
## Assignment 6 checks: Health, Hazard hierarchy, Spawner limit, Slash lifetime.
## Run: godot --headless --path . -s tools/test_a6.gd   (exit code 0 = all PASS, 1 = any FAIL)

const HAZARD_SCENES: Dictionary = {
	"Rock": "res://scenes/hazards/rock.tscn",
	"BombHazard": "res://scenes/hazards/bomb.tscn",
	"Potion": "res://scenes/hazards/potion.tscn",
}
const SPAWNER_SCRIPT: String = "res://scripts/spawner.gd"
const SLASH_SCENE: String = "res://scenes/weapons/slash.tscn"
const WATCHDOG_SECONDS: float = 30.0

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
	spawner.set("max_alive", 3)
	spawner.set("interval", 100.0)
	world.add_child(spawner)
	await process_frame
	var spawned: int = 0
	for i in 10:
		if spawner.call("spawn_one") != null:
			spawned += 1
	var alive: int = get_nodes_in_group("hazard").size()
	_check("spawner respects max_alive", spawned == 3 and alive == 3, "spawned=%d alive=%d (max 3)" % [spawned, alive])
	world.queue_free()
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
