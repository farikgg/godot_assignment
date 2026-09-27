extends CharacterBody3D

@export var SPEED: float = 5.0
@export var JUMP_VELOCITY: float = 6.0

@onready var mesh: MeshInstance3D = $MeshInstance3D

const BALL_COLORS: Array[Color] = [Color.RED, Color.DODGER_BLUE, Color.GREEN]

func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = BALL_COLORS[Profile.ball_color_index]
	mesh.material_override = material

func _physics_process(delta: float) -> void:
	# гравитация — Godot сам не тянет объект вниз, это делаем мы
	if not is_on_floor():
		velocity += get_gravity() * delta

	# прыжок — только если стоим на полу
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# движение по WASD
	var input_dir: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	var direction: Vector3 = (
		transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = 0
		velocity.z = 0

	move_and_slide()
