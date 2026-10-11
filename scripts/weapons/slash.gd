class_name Slash
extends Area3D

@export var lifetime: float = 0.15
@export var damage: int = 1

# instance ids already hit: every body is hit exactly once
var _hit: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_try_hit)
	get_tree().create_timer(lifetime, false).timeout.connect(queue_free)

func _physics_process(_delta: float) -> void:
	# bodies that were already inside when the slash appeared may not raise body_entered
	for body in get_overlapping_bodies():
		_try_hit(body)

func _try_hit(body: Node3D) -> void:
	if body == null or _hit.has(body.get_instance_id()):
		return
	if not body.has_method("hit_by_weapon"):
		return
	_hit[body.get_instance_id()] = true
	body.call("hit_by_weapon", damage)
