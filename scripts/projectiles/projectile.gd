class_name Projectile
extends Area3D
## Base of enemy shots: flies along `direction`, hurts the hero through their Health,
## breaks on walls and props, ignores enemies, and frees itself after `lifetime` (pause-aware Timer).

@export var speed: float = 8.0
@export var damage: int = 1
@export var lifetime: float = 4.0
## Optional burst spawned where the shot ends.
@export var impact_fx: PackedScene

var direction: Vector3 = Vector3.FORWARD
var _spent: bool = false

func _ready() -> void:
	monitorable = false
	body_entered.connect(_on_body_entered)
	var timer := Timer.new()
	timer.name = "LifetimeTimer"
	timer.one_shot = true
	timer.wait_time = lifetime
	timer.autostart = true
	timer.timeout.connect(queue_free)
	add_child(timer)

## Places the shot and sends it along `dir` (call after adding it to the tree).
func launch(from: Vector3, dir: Vector3) -> void:
	global_position = from
	direction = dir.normalized()

func _physics_process(delta: float) -> void:
	if not _spent:
		global_position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if _spent or body.is_in_group("enemy"):
		return
	if body.is_in_group("player"):
		_hurt(body)
	_expire()

## Damages a body through its Health child; false if it has none.
func _hurt(body: Node) -> bool:
	var health: Health = body.get_node_or_null("Health") as Health
	if health == null:
		push_error("Projectile: %s has no Health child" % body.name)
		return false
	health.take_damage(damage)
	return true

func _expire() -> void:
	if _spent:
		return
	_spent = true
	if impact_fx != null:
		var fx: Node3D = impact_fx.instantiate() as Node3D
		var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
		parent.add_child(fx)
		fx.global_position = global_position
	queue_free()
