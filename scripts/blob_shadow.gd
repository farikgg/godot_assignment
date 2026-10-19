extends MeshInstance3D
## Round shadow under the hero: shows where they will land, which the isometric camera hides otherwise.

## Longest drop the shadow still follows; over a deeper pit it disappears.
@export var max_distance: float = 12.0
## Shadow scale at the feet and at max_distance (it shrinks as the hero rises).
@export var near_scale: float = 1.0
@export var far_scale: float = 0.45
## Lift above the surface so the disc doesn't z-fight with the floor.
@export var surface_offset: float = 0.02

@onready var _owner_body: CollisionObject3D = get_parent() as CollisionObject3D

func _ready() -> void:
	assert(_owner_body != null, "BlobShadow must be a child of the player body")
	# follows the ground, not the jumping body
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _physics_process(_delta: float) -> void:
	var from: Vector3 = _owner_body.global_position + Vector3.UP * 0.1
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * max_distance)
	query.exclude = [_owner_body.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		visible = false
		return
	visible = true
	var point: Vector3 = hit["position"]
	global_position = point + Vector3.UP * surface_offset
	var height: float = clampf((from.y - point.y) / max_distance, 0.0, 1.0)
	scale = Vector3.ONE * lerpf(near_scale, far_scale, height)
