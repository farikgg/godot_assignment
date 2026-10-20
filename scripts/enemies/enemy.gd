class_name Enemy
extends CharacterBody3D
## Base of every enemy: group `enemy` (touching it hurts the hero through the hero's Hurtbox),
## a Health child, weapon hits with a short knockback, gravity, the model turning towards its
## motion, clips played only when the model has them, and the shared death.
## Subclasses set `desired_velocity` in _think() and react in _on_damaged() / _on_died().

signal died

@export var turn_speed: float = 8.0
@export var knockback_speed: float = 5.0
@export var knockback_time: float = 0.2
## Seconds the body stays after death before it is freed; <= 0 keeps it.
@export var free_delay: float = 1.5
## Below this height (fell into a pit) the enemy is removed.
@export var fall_limit_y: float = -20.0

@export_group("Animations")
## Clip names of the Kenney models; an empty or missing clip is skipped.
@export var anim_idle: StringName = &"idle"
@export var anim_walk: StringName = &"walk"
@export var anim_run: StringName = &"sprint"
@export var anim_attack: StringName = &"attack-melee-right"
@export var anim_die: StringName = &"die"

@onready var health: Health = $Health
@onready var visual: Node3D = $Visual

## Horizontal velocity the subclass wants this frame.
var desired_velocity: Vector3 = Vector3.ZERO
var _anim: AnimationPlayer
var _dead: bool = false
var _last_hp: int = 0
var _knockback_left: float = 0.0

func _ready() -> void:
	assert(health != null, "Enemy needs a Health child")
	assert(visual != null, "Enemy needs a Visual child")
	add_to_group("enemy")
	_find_animation_player()
	_last_hp = health.current
	health.changed.connect(_on_health_changed)
	health.died.connect(_die)
	play_anim(anim_idle)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if global_position.y < fall_limit_y:
		queue_free()
		return
	if _dead:
		desired_velocity = Vector3.ZERO
	elif _knockback_left > 0.0:
		_knockback_left -= delta
	else:
		_think(delta)
	if _knockback_left <= 0.0:
		velocity.x = desired_velocity.x
		velocity.z = desired_velocity.z
	move_and_slide()
	if not _dead and _knockback_left <= 0.0 and desired_velocity.length_squared() > 0.01:
		face_direction(desired_velocity, delta)

## Per-frame decision of the subclass: set desired_velocity, turn, change state.
func _think(_delta: float) -> void:
	pass

## Called after a hit that did not kill.
func _on_damaged() -> void:
	pass

## Called once on death, after the base has played the clip and disabled collisions.
func _on_died() -> void:
	pass

func is_dead() -> bool:
	return _dead

## Sword hit: damage plus a short push away from the hero.
func hit_by_weapon(damage: int = 1) -> void:
	if _dead:
		return
	var before: int = health.current
	health.take_damage(damage)
	if health.current >= before or _dead or knockback_speed <= 0.0:
		return
	var hero: Node3D = get_hero()
	var away: Vector3 = global_position - hero.global_position if hero != null else -get_facing()
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.0001 else -get_facing()
	velocity.x = away.x * knockback_speed
	velocity.z = away.z * knockback_speed
	_knockback_left = knockback_time

## The hero, or null if there is none.
func get_hero() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

## The hero while alive, otherwise null.
func get_live_hero() -> Node3D:
	var hero: Node3D = get_hero()
	if hero == null:
		return null
	var hero_health: Health = hero.get_node_or_null("Health") as Health
	return hero if hero_health != null and not hero_health.is_dead() else null

func flat_distance_to(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()

## Unit vector the model faces on the ground plane (models look along +Z).
func get_facing() -> Vector3:
	var forward: Vector3 = visual.global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.BACK

func face_direction(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(direction.x, direction.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

func face_towards(point: Vector3, delta: float) -> void:
	face_direction(point - global_position, delta)

## Plays a clip if the model has it and it is not already playing. False if it is missing.
func play_anim(clip: StringName, blend: float = 0.15, speed: float = 1.0) -> bool:
	if not has_anim(clip):
		return false
	if _anim.current_animation != clip:
		_anim.play(clip, blend, speed)
	return true

## Starts a clip from its first frame even if it is already playing.
func restart_anim(clip: StringName, speed: float = 1.0) -> bool:
	if not has_anim(clip):
		return false
	_anim.play(clip, 0.05, speed)
	_anim.seek(0.0, true)
	return true

func has_anim(clip: StringName) -> bool:
	return _anim != null and clip != &"" and _anim.has_animation(clip)

func anim_length(clip: StringName) -> float:
	return _anim.get_animation(clip).length if has_anim(clip) else 0.0

func _find_animation_player() -> void:
	for node in visual.find_children("*", "AnimationPlayer", true, false):
		_anim = node as AnimationPlayer
		break
	if _anim == null:
		push_warning("Enemy %s: model has no AnimationPlayer" % name)
		return
	# glTF clips import without a loop flag
	for clip in [anim_idle, anim_walk, anim_run]:
		if has_anim(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

func _on_health_changed(current: int, _max_hp: int) -> void:
	if current < _last_hp and current > 0:
		_on_damaged()
	_last_hp = current

func _die() -> void:
	if _dead:
		return
	_dead = true
	desired_velocity = Vector3.ZERO
	_knockback_left = 0.0
	# no longer an enemy: the hero's Hurtbox and sword ignore it, it only rests on the floor
	remove_from_group("enemy")
	collision_layer = 0
	restart_anim(anim_die)
	_on_died()
	died.emit()
	if free_delay > 0.0:
		get_tree().create_timer(free_delay, false).timeout.connect(queue_free)
