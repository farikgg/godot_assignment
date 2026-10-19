@tool
class_name FloorSlab
extends StaticBody3D
## Box of solid floor whose top face is at the node's origin. Levels set `size` per instance,
## so islands, ledges and pillars need no meshes or shapes of their own.

## Footprint in metres: x along X, y along Z.
@export var size: Vector2 = Vector2(4.0, 4.0):
	set(value):
		size = value
		_rebuild()
## Depth below the top face; pillars use a large value so they reach down into the floor or the pit.
@export var thickness: float = 1.0:
	set(value):
		thickness = value
		_rebuild()
@export var material: Material:
	set(value):
		material = value
		_rebuild()

@onready var _shape_node: CollisionShape3D = $CollisionShape3D
@onready var _mesh_node: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_node_ready():
		return
	var extents := Vector3(maxf(size.x, 0.1), maxf(thickness, 0.05), maxf(size.y, 0.1))
	# fresh resources per instance: a shared shape would resize every slab at once
	var box := BoxShape3D.new()
	box.size = extents
	_shape_node.shape = box
	var mesh := BoxMesh.new()
	mesh.size = extents
	mesh.material = material
	_mesh_node.mesh = mesh
	var centre := Vector3(0.0, -extents.y * 0.5, 0.0)
	_shape_node.position = centre
	_mesh_node.position = centre
