extends Node3D
## Cave-in: every `interval` seconds a shadow grows on the floor, then a hazard drops from the ceiling.

## Any scenes whose root extends Hazard; repeat a scene to make it more likely.
@export var hazard_scenes: Array[PackedScene] = []
@export var interval: float = 1.5
## Drop height above the spawner (under the ceiling), metres.
@export var spawn_height: float = 6.0
@export var max_alive: int = 15
## Spawn rectangle on the floor, centred on the spawner (the map floor is 20 × 20).
@export var area_size: Vector2 = Vector2(18, 18)
## How long the warning shadow grows before the drop.
@export var telegraph_time: float = 0.8
@export var shadow_radius: float = 0.7
@export var shadow_color: Color = Color(0.05, 0.05, 0.09, 0.55)
## Optional rumble played when a drop is telegraphed.
@export_file("*.ogg", "*.wav") var rumble_sound_path: String = "res://assets/audio/rumble.ogg"

var _rng := RandomNumberGenerator.new()
var _timer: Timer
var _pending: int = 0
var _shadow_mesh: CylinderMesh
var _rumble: AudioStream

func _ready() -> void:
	_rng.randomize()
	if hazard_scenes.is_empty():
		push_error("Spawner: hazard_scenes is empty")
	_shadow_mesh = _make_shadow_mesh()
	_rumble = Sfx.load_stream(rumble_sound_path)
	# InvokeRepeating: a looping Timer that stops while the tree is paused
	_timer = Timer.new()
	_timer.wait_time = interval
	_timer.autostart = true
	_timer.timeout.connect(spawn_one)
	add_child(_timer)

## Hazards on the map plus drops still being telegraphed.
func alive_count() -> int:
	return get_tree().get_nodes_in_group("hazard").size() + _pending

## Starts a telegraphed drop; false when the limit is reached.
func spawn_one() -> bool:
	if hazard_scenes.is_empty() or alive_count() >= max_alive:
		return false
	var scene: PackedScene = hazard_scenes[_rng.randi_range(0, hazard_scenes.size() - 1)]
	if scene == null:
		push_error("Spawner: empty slot in hazard_scenes")
		return false
	var x: float = global_position.x + _rng.randf_range(-area_size.x * 0.5, area_size.x * 0.5)
	var z: float = global_position.z + _rng.randf_range(-area_size.y * 0.5, area_size.y * 0.5)
	var drop_y: float = global_position.y + spawn_height
	var ground_y: float = _ground_height(x, z, drop_y)
	_pending += 1
	Sfx.play(_rumble, self)
	var shadow: MeshInstance3D = _spawn_shadow(Vector3(x, ground_y + 0.03, z))
	var tween: Tween = shadow.create_tween()
	tween.tween_property(shadow, "scale", Vector3(1.0, 1.0, 1.0), telegraph_time).from(Vector3(0.15, 1.0, 0.15))
	tween.finished.connect(_drop.bind(scene, Vector3(x, drop_y, z), shadow))
	return true

func _drop(scene: PackedScene, at: Vector3, shadow: MeshInstance3D) -> Hazard:
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
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, global_position.y - 2.0, z))
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else global_position.y

func _spawn_shadow(at: Vector3) -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	shadow.mesh = _shadow_mesh
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(shadow)
	shadow.global_position = at
	return shadow

func _make_shadow_mesh() -> CylinderMesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = shadow_color
	var mesh := CylinderMesh.new()
	mesh.top_radius = shadow_radius
	mesh.bottom_radius = shadow_radius
	mesh.height = 0.02
	mesh.radial_segments = 32
	mesh.material = material
	return mesh
