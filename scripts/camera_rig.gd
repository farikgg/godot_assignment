extends Node3D

const STEP_DEGREES: float = 90.0

@export var turn_duration: float = 0.35
@export var follow_speed: float = 5.0
## The pivot stays put while the player is closer than this (metres, ground plane).
@export var dead_zone: float = 1.5

# accumulated, never wrapped to 0–360: a wrapped target would make the tween
# spin the long way round when crossing 360 -> 0
var _target_yaw: float = 0.0
var _tween: Tween
var _target: Node3D

func _ready() -> void:
	_target_yaw = rotation_degrees.y
	_target = get_tree().get_first_node_in_group("player") as Node3D
	if _target == null:
		push_error("CameraRig: no Node3D in group \"player\"")
		return
	# start on the player instead of flying in from the map centre
	global_position = _ground_point()

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var offset: Vector3 = _ground_point() - global_position
	var distance: float = offset.length()
	if distance <= dead_zone:
		return
	var desired: Vector3 = global_position + offset * ((distance - dead_zone) / distance)
	# frame-rate independent exponential smoothing
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))

# player position on the pivot's own height, so jumps don't bob the camera
func _ground_point() -> Vector3:
	return Vector3(_target.global_position.x, global_position.y, _target.global_position.z)

func _unhandled_input(event: InputEvent) -> void:
	# allow_echo = false: holding the key must not repeat the turn
	if event.is_action_pressed("camera_left", false):
		_turn_by(-STEP_DEGREES)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_right", false):
		_turn_by(STEP_DEGREES)
		get_viewport().set_input_as_handled()

func _turn_by(delta_degrees: float) -> void:
	_target_yaw += delta_degrees
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "rotation_degrees:y", _target_yaw, turn_duration)
