extends RigidBody3D

@export var force: float = 8.0

@onready var mesh: MeshInstance3D = $MeshInstance3D

const BALL_COLORS: Array[Color] = [Color.RED, Color.DODGER_BLUE, Color.GREEN]

var _is_dead: bool = false

func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = BALL_COLORS[Profile.ball_color_index]
	mesh.material_override = material

	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)

	# ввод считается относительно экрана, а не мира
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		direction = direction.rotated(Vector3.UP, camera.global_rotation.y)

	apply_central_force(direction * force)

func _on_body_entered(body: Node) -> void:
	if _is_dead or not body.is_in_group("enemy"):
		return
	_is_dead = true
	print("Game over")
	get_tree().reload_current_scene.call_deferred()
