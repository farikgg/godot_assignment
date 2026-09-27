extends Area3D

signal collected

@export var SPIN_SPEED: float = 2.0
@export var BOB_HEIGHT: float = 0.15
@export var BOB_SPEED: float = 2.5

var _TIME: float = 0.0
var _BASE_Y: float

func _ready() -> void:
	add_to_group("coins")
	_BASE_Y = position.y

func _process(delta: float) -> void:
	global_rotate(Vector3.UP, SPIN_SPEED * delta)
	_TIME += delta
	position.y = _BASE_Y + sin(_TIME * BOB_SPEED) * BOB_HEIGHT

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		collected.emit()
		queue_free()
