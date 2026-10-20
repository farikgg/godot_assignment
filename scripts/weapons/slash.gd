class_name Slash
extends Area3D

@export var lifetime: float = 0.15
@export var damage: int = 1
## Sparks spawned on every body the slash hits (enemy, boss, keg).
@export var hit_fx: PackedScene

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
	# sparks first: a keg or a dying enemy may free itself inside hit_by_weapon
	_spawn_sparks(body)
	body.call("hit_by_weapon", damage)

func _spawn_sparks(body: Node3D) -> void:
	if hit_fx == null:
		return
	var fx: Node3D = hit_fx.instantiate() as Node3D
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	parent.add_child(fx)
	# between the blade and the body, at chest height
	fx.global_position = global_position.lerp(body.global_position + Vector3.UP * 0.6, 0.6)
