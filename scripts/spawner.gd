extends Node3D
## Cave-in: every data.interval seconds a shadow grows on the floor, then a hazard drops from the ceiling.
## What falls, how often and where is the SpawnerData (resources/spawners/).

## Shadow sits this far above the ground so it does not flicker with the floor.
const SHADOW_LIFT: float = 0.03  # m
## The ground ray reaches this far below the spawner.
const GROUND_RAY_DEPTH: float = 2.0  # m

@export var data: SpawnerData
## Drop height above the spawner (under the ceiling), metres.
@export var spawn_height: float = 6.0
@export var shadow_radius: float = 0.7
@export var shadow_color: Color = Color(0.05, 0.05, 0.09, 0.55)
## Optional rumble played when a drop is telegraphed.
@export var rumble_sound: AudioStream
## Warning circle scene (shared with the boss's fire rain).
@export var marker_scene: PackedScene = preload("res://scenes/fx/telegraph_marker.tscn")

var _rng := RandomNumberGenerator.new()
var _timer: Timer
var _pending: int = 0
var _weights := PackedFloat32Array()
var _valid: bool = false

func _ready() -> void:
	_rng.randomize()
	# InvokeRepeating: a looping Timer that stops while the tree is paused
	_timer = Timer.new()
	_timer.timeout.connect(spawn_one)
	add_child(_timer)
	configure(data)

## Applies `new_data` (also used by a level that sets the cave-in from its LevelData).
## Broken data stops the spawner with an error instead of dropping garbage.
func configure(new_data: SpawnerData) -> void:
	data = new_data
	_valid = _validate()
	_timer.stop()
	if _valid:
		_timer.wait_time = data.interval
		_timer.start()

## Hazards on the map plus drops still being telegraphed.
func alive_count() -> int:
	return get_tree().get_nodes_in_group("hazard").size() + _pending

func is_valid() -> bool:
	return _valid

## Starts a telegraphed drop; false when the limit is reached or the setup is broken.
func spawn_one() -> bool:
	if not _valid or alive_count() >= data.max_alive:
		return false
	var scene: PackedScene = data.hazard_scenes[_rng.rand_weighted(_weights)]
	if scene == null:
		push_error("Spawner: empty slot in hazard_scenes")
		return false
	var half: Vector2 = data.area_size * 0.5
	var x: float = global_position.x + _rng.randf_range(-half.x, half.x)
	var z: float = global_position.z + _rng.randf_range(-half.y, half.y)
	var drop_y: float = global_position.y + spawn_height
	var ground_y: float = _ground_height(x, z, drop_y)
	_pending += 1
	Sfx.play(rumble_sound, self)
	var shadow: TelegraphMarker = _spawn_shadow(Vector3(x, ground_y + SHADOW_LIFT, z))
	shadow.finished.connect(_drop.bind(scene, Vector3(x, drop_y, z), shadow))
	shadow.grow(data.telegraph_time)
	return true

func _drop(scene: PackedScene, at: Vector3, shadow: TelegraphMarker) -> Hazard:
	_pending -= 1
	if is_instance_valid(shadow):
		shadow.queue_free()
	var node: Node = scene.instantiate()
	var hazard: Hazard = node as Hazard
	if hazard == null:
		push_error("Spawner: %s is not a Hazard" % scene.resource_path)
		node.free()
		return null
	hazard.rotation.y = _rng.randf_range(0.0, TAU)
	get_parent().add_child(hazard)
	hazard.global_position = at
	return hazard

# top of whatever the hazard will land on (floor, wall, prop), so the shadow sits on it
func _ground_height(x: float, z: float, from_y: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, global_position.y - GROUND_RAY_DEPTH, z))
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else global_position.y

func _spawn_shadow(at: Vector3) -> TelegraphMarker:
	var shadow: TelegraphMarker = marker_scene.instantiate() as TelegraphMarker
	shadow.radius = shadow_radius
	shadow.color = shadow_color
	get_parent().add_child(shadow)
	shadow.global_position = at
	return shadow

func _validate() -> bool:
	if data == null:
		push_error("Spawner %s: no SpawnerData, spawner stopped" % name)
		return false
	var problems: PackedStringArray = data.validate()
	if not problems.is_empty():
		push_error("Spawner %s: %s: %s; spawner stopped" % [name, data.resource_path, ", ".join(problems)])
		return false
	_weights = PackedFloat32Array(data.spawn_weights)
	return true
