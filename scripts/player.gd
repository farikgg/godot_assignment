extends RigidBody3D

@export var force: float = 12.0
@export var max_speed: float = 5.0
@export var jump_impulse: float = 5.0

@onready var mesh: MeshInstance3D = $MeshInstance3D

const BALL_COLORS: Array[Color] = [Color.RED, Color.DODGER_BLUE, Color.GREEN]

var _is_dead: bool = false
var _on_ground: bool = false

func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = BALL_COLORS[Profile.ball_color_index]
	mesh.material_override = material

	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_on_ground = false
	for i in state.get_contact_count():
		# нормаль смотрит вверх: пол, скат лестницы (стена даёт y около 0)
		if state.get_contact_local_normal(i).y > 0.5:
			_on_ground = true
			return

func _physics_process(_delta: float) -> void:
	if _on_ground and Input.is_action_just_pressed("jump"):
		apply_central_impulse(Vector3.UP * jump_impulse)

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)

	var camera := get_viewport().get_camera_3d()
	if camera != null:
		direction = direction.rotated(Vector3.UP, camera.global_rotation.y)

	var flat_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if flat_velocity.length() < max_speed or flat_velocity.dot(direction) <= 0.0:
		apply_central_force(direction * force)

func _on_body_entered(body: Node) -> void:
	if _is_dead or not body.is_in_group("enemy"):
		return
	_is_dead = true
	print("Game over")
	get_tree().reload_current_scene.call_deferred()
