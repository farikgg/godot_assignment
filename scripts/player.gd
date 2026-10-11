extends RigidBody3D

@export var force: float = 12.0
@export var max_speed: float = 5.0
@export var jump_impulse: float = 5.0
@export var knockback_impulse: float = 6.0
@export var knockback_lift: float = 2.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var health: Health = $Health

const BALL_COLORS: Array[Color] = [Color.RED, Color.DODGER_BLUE, Color.GREEN]

var _is_dead: bool = false
var _on_ground: bool = false

func _ready() -> void:
	assert(health != null, "Player needs a Health child")
	health.died.connect(_on_died)
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
	if _is_dead:
		return
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
	var enemy: Node3D = body as Node3D
	if enemy == null:
		return
	# push away horizontally from the enemy; straight back if we're right on top of it
	var away: Vector3 = global_position - enemy.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = -Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if away.length_squared() < 0.0001:
		away = Vector3.BACK
	apply_central_impulse(away.normalized() * knockback_impulse + Vector3.UP * knockback_lift)
	health.take_damage(1)

func _on_died() -> void:
	_is_dead = true
