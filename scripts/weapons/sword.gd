extends Node3D

@export var cooldown: float = 0.5
@export var slash_scene: PackedScene
## Hitbox centre in front of the ball, metres.
@export var slash_distance: float = 0.9
## Where the sword hangs, in the facing frame (x right, y up, -z forward).
@export var hold_offset: Vector3 = Vector3(0.65, 0.2, -0.1)
@export var swing_arc_degrees: float = 75.0
@export var swing_time: float = 0.12

@onready var _player: RigidBody3D = get_parent() as RigidBody3D
@onready var _pivot: Node3D = $Pivot
@onready var _swing_sfx: AudioStreamPlayer = $SwingSfx

var _facing: Vector3 = Vector3.FORWARD
var _last_attack_ms: int = -1_000_000
var _tween: Tween

func _ready() -> void:
	assert(_player != null, "Sword must be a child of the player RigidBody3D")
	if slash_scene == null:
		push_error("Sword: slash_scene is not set")
	# the ball rolls, so the sword must not inherit its rotation
	top_level = true
	_follow()

func _process(_delta: float) -> void:
	var flat := Vector3(_player.linear_velocity.x, 0.0, _player.linear_velocity.z)
	if flat.length() > 0.3:
		_facing = flat.normalized()
	_follow()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack", false):
		if try_attack():
			get_viewport().set_input_as_handled()

func _follow() -> void:
	var facing_basis := Basis.looking_at(_facing, Vector3.UP)
	global_transform = Transform3D(facing_basis, _player.global_position + facing_basis * hold_offset)

func try_attack() -> bool:
	var health: Health = _player.get_node_or_null("Health") as Health
	if health != null and health.is_dead():
		return false
	var now: int = Time.get_ticks_msec()
	if now - _last_attack_ms < int(cooldown * 1000.0):
		return false
	_last_attack_ms = now
	_play_swing()
	_spawn_slash()
	_swing_sfx.play()
	return true

func _play_swing() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_pivot.rotation_degrees.y = swing_arc_degrees
	_tween = create_tween()
	_tween.tween_property(_pivot, "rotation_degrees:y", -swing_arc_degrees, swing_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_pivot, "rotation_degrees:y", 0.0, swing_time * 1.5)

func _spawn_slash() -> void:
	if slash_scene == null:
		return
	var slash: Slash = slash_scene.instantiate() as Slash
	if slash == null:
		push_error("Sword: slash_scene root is not a Slash")
		return
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else _player.get_parent()
	parent.add_child(slash)
	slash.global_transform = Transform3D(Basis.looking_at(_facing, Vector3.UP),
		_player.global_position + _facing * slash_distance)
