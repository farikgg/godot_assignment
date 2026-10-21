extends GPUParticles3D
## Slow dust hanging in the air. The emission box follows the camera's pivot on the ground plane,
## so a long level needs only one small emitter; particles live in world space and drift on their own.

func _ready() -> void:
	top_level = true
	_follow()

func _process(_delta: float) -> void:
	_follow()

func _follow() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var pivot: Node3D = camera.get_parent() as Node3D
	var centre: Vector3 = pivot.global_position if pivot != null else camera.global_position
	global_position = Vector3(centre.x, position.y, centre.z)
