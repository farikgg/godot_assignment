extends Node3D

const STEP_DEGREES: float = 90.0

@export var turn_duration: float = 0.35

# accumulated, never wrapped to 0–360: a wrapped target would make the tween
# spin the long way round when crossing 360 -> 0
var _target_yaw: float = 0.0
var _tween: Tween

func _ready() -> void:
	_target_yaw = rotation_degrees.y

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
