extends Node3D

@export var open_offset: Vector3 = Vector3(0, 1.6, 0)
@export var open_time: float = 0.6

@onready var body: AnimatableBody3D = $Body
@onready var sensor: Area3D = $Sensor

var _closed_position: Vector3
var _tween: Tween

func _ready() -> void:
	if body == null or sensor == null:
		push_error("Door: missing Body or Sensor child")
		return
	_closed_position = body.position
	sensor.body_entered.connect(_on_sensor_body_entered)
	sensor.body_exited.connect(_on_sensor_body_exited)

func _on_sensor_body_entered(other: Node3D) -> void:
	if other != null and other.is_in_group("player"):
		_move_body_to(_closed_position + open_offset)

func _on_sensor_body_exited(other: Node3D) -> void:
	if other != null and other.is_in_group("player"):
		_move_body_to(_closed_position)

func _move_body_to(target: Vector3) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	# scale duration by remaining distance so reversing mid-move keeps the same speed
	var full_distance: float = open_offset.length()
	var ratio: float = body.position.distance_to(target) / full_distance if full_distance > 0.0 else 0.0
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(body, "position", target, open_time * ratio) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
