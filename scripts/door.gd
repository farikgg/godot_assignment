extends Node3D

@export var open_angle: float = 100.0
@export var open_time: float = 0.6

@onready var body: AnimatableBody3D = $Body
@onready var sensor: Area3D = $Sensor

var _tween: Tween

func _ready() -> void:
	if body == null or sensor == null:
		push_error("Door: missing Body or Sensor child")
		return
	sensor.body_entered.connect(_on_sensor_body_entered)
	sensor.body_exited.connect(_on_sensor_body_exited)

func _on_sensor_body_entered(other: Node3D) -> void:
	if not other.is_in_group("player"):
		return
	# дверь открывается от игрока, в сторону, где он не стоит
	var side: float = signf(to_local(other.global_position).z)
	_swing_to((side if side != 0.0 else 1.0) * open_angle)

func _on_sensor_body_exited(other: Node3D) -> void:
	if other.is_in_group("player"):
		_swing_to(0.0)

func _swing_to(target_degrees: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var ratio: float = absf(target_degrees - body.rotation_degrees.y) / maxf(open_angle, 0.001)
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(body, "rotation_degrees:y", target_degrees, open_time * ratio) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
