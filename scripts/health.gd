class_name Health
extends Node

signal changed(current: int, max_hp: int)
signal died

@export var max_hp: int = 3
@export var invincible_time: float = 2.0
@export var blink_interval: float = 0.1
## Visual node that blinks while invincible (a mesh, not the RigidBody itself).
@export var blink_target: NodePath

var current: int = 0
var _invincible: bool = false
var _dead: bool = false
var _blink_node: Node3D

func _ready() -> void:
	current = max_hp
	if not blink_target.is_empty():
		_blink_node = get_node_or_null(blink_target) as Node3D
		if _blink_node == null:
			push_error("Health: blink_target %s is not a Node3D" % blink_target)
	changed.emit(current, max_hp)

func is_invincible() -> bool:
	return _invincible

func is_dead() -> bool:
	return _dead

func take_damage(amount: int) -> void:
	if amount <= 0 or _dead or _invincible:
		return
	current = maxi(current - amount, 0)
	changed.emit(current, max_hp)
	if current == 0:
		_dead = true
		died.emit()
		return
	_invincibility()

func heal(amount: int) -> void:
	if amount <= 0 or _dead:
		return
	var healed: int = mini(current + amount, max_hp)
	if healed == current:
		return
	current = healed
	changed.emit(current, max_hp)

# Coroutine: blinks blink_target until invincible_time runs out.
# The timers don't run while the tree is paused, so the blink freezes with the game.
func _invincibility() -> void:
	_invincible = true
	var elapsed: float = 0.0
	while elapsed < invincible_time:
		await get_tree().create_timer(blink_interval, false).timeout
		if not is_inside_tree():
			return
		elapsed += blink_interval
		if _blink_node != null:
			_blink_node.visible = not _blink_node.visible
	if _blink_node != null:
		_blink_node.visible = true
	_invincible = false
