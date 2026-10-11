extends Node3D

## Any scenes whose root extends Hazard; repeat a scene to make it more likely.
@export var hazard_scenes: Array[PackedScene] = []
@export var interval: float = 1.5
@export var spawn_height: float = 12.0
@export var max_alive: int = 15
## Spawn rectangle on the floor, centred on the spawner (the map floor is 20 × 20).
@export var area_size: Vector2 = Vector2(18, 18)

var _rng := RandomNumberGenerator.new()
var _timer: Timer

func _ready() -> void:
	_rng.randomize()
	if hazard_scenes.is_empty():
		push_error("Spawner: hazard_scenes is empty")
	# InvokeRepeating: a looping Timer that stops while the tree is paused
	_timer = Timer.new()
	_timer.wait_time = interval
	_timer.autostart = true
	_timer.timeout.connect(spawn_one)
	add_child(_timer)

func alive_count() -> int:
	return get_tree().get_nodes_in_group("hazard").size()

func spawn_one() -> Hazard:
	if hazard_scenes.is_empty() or alive_count() >= max_alive:
		return null
	var scene: PackedScene = hazard_scenes[_rng.randi_range(0, hazard_scenes.size() - 1)]
	if scene == null:
		push_error("Spawner: empty slot in hazard_scenes")
		return null
	var node: Node = scene.instantiate()
	var hazard: Hazard = node as Hazard
	if hazard == null:
		push_error("Spawner: %s is not a Hazard" % scene.resource_path)
		node.free()
		return null
	var offset := Vector3(
		_rng.randf_range(-area_size.x * 0.5, area_size.x * 0.5),
		spawn_height,
		_rng.randf_range(-area_size.y * 0.5, area_size.y * 0.5))
	hazard.rotation.y = _rng.randf_range(0.0, TAU)
	get_parent().add_child(hazard)
	hazard.global_position = global_position + offset
	return hazard
