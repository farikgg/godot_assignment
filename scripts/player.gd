extends CharacterBody3D

@export var move_speed: float = 5.0
@export var acceleration: float = 30.0
@export var jump_velocity: float = 5.0
## How fast Visual turns towards the movement direction (higher = snappier).
@export var turn_speed: float = 12.0
@export var knockback_speed: float = 7.0
@export var knockback_lift: float = 3.0
## Input is ignored for this long after a hit so the knockback is visible.
@export var knockback_time: float = 0.25
## Horizontal speed above which the run animation plays.
@export var run_threshold: float = 0.5
@export_file("*.ogg", "*.wav") var hurt_sound_path: String = "res://assets/audio/hurt.ogg"

@onready var visual: Node3D = $Visual
@onready var health: Health = $Health
@onready var hurtbox: Area3D = $Hurtbox
@onready var hurt_sfx: AudioStreamPlayer = $HurtSfx

var _data: CharacterData
var _model: Node3D
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _hand_socket: Node3D
var _is_dead: bool = false
var _last_hp: int = 0
var _knockback_left: float = 0.0
# attack / hit / die run to the end before idle or run may take over
var _action_playing: bool = false

func _ready() -> void:
	assert(health != null, "Player needs a Health child")
	assert(visual != null, "Player needs a Visual child")
	_build_model()
	hurt_sfx.stream = Sfx.load_stream(hurt_sound_path)
	health.died.connect(_on_died)
	health.changed.connect(_on_health_changed)
	_last_hp = health.current
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)

func _build_model() -> void:
	_data = Roster.get_by_id(Profile.character_id)
	if _data == null or _data.model == null:
		push_error("Player: no character model for id '%s'" % Profile.character_id)
		return
	_model = _data.model.instantiate() as Node3D
	visual.add_child(_model)
	visual.scale = Vector3.ONE * _data.model_scale
	for node in _model.find_children("*", "AnimationPlayer", true, false):
		_anim = node as AnimationPlayer
		break
	for node in _model.find_children("*", "Skeleton3D", true, false):
		_skeleton = node as Skeleton3D
		break
	if _anim == null:
		push_warning("Player: model of '%s' has no AnimationPlayer" % _data.id)
	else:
		_anim.animation_finished.connect(_on_animation_finished)
		# glTF clips import without a loop flag
		for loop_name in [_data.anim_idle, _data.anim_run]:
			if _has_anim(loop_name):
				_anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
	_play_locomotion()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	_knockback_left = maxf(_knockback_left - delta, 0.0)

	var direction := Vector3.ZERO
	if not _is_dead and _knockback_left <= 0.0:
		if is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
		var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		direction = Vector3(input_dir.x, 0.0, input_dir.y)
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			direction = direction.rotated(Vector3.UP, camera.global_rotation.y)

	horizontal = horizontal.move_toward(direction * move_speed, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	if direction.length_squared() > 0.01:
		# the model looks along +Z
		var target_yaw: float = atan2(direction.x, direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	if not _action_playing and not _is_dead:
		_play_locomotion()

## Unit vector the character faces on the ground plane.
func get_facing() -> Vector3:
	var forward: Vector3 = visual.global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.BACK

func get_character_data() -> CharacterData:
	return _data

func get_skeleton() -> Skeleton3D:
	return _skeleton

## Node that follows the right hand: a BoneAttachment3D on hand_bone, or a Marker3D at the right
## side when the rig has no such bone. Its local space is in model units, arm along -X.
func get_hand_socket() -> Node3D:
	if _hand_socket != null:
		return _hand_socket
	var bone: StringName = _data.hand_bone if _data != null else &""
	if _skeleton != null and bone != &"" and _skeleton.find_bone(bone) != -1:
		var attachment := BoneAttachment3D.new()
		attachment.name = "HandSocket"
		attachment.bone_name = bone
		_skeleton.add_child(attachment)
		_hand_socket = attachment
	else:
		push_warning("Player: bone '%s' not found, sword goes to the right side" % bone)
		var marker := Marker3D.new()
		marker.name = "HandSocket"
		marker.position = Vector3(-0.3, 0.2, 0.05)
		visual.add_child(marker)
		_hand_socket = marker
	return _hand_socket

## Plays the hero's attack clip; false if the hero has none (the sword then animates itself).
func play_attack() -> bool:
	if _is_dead or _data == null:
		return false
	return _play_action(_data.anim_attack)

func _play_locomotion() -> void:
	if _anim == null or _data == null:
		return
	var speed: float = Vector2(velocity.x, velocity.z).length()
	var clip: StringName = _data.anim_run if speed > run_threshold else _data.anim_idle
	if _has_anim(clip) and _anim.current_animation != clip:
		_anim.play(clip, 0.15)

func _play_action(clip: StringName) -> bool:
	if not _has_anim(clip):
		return false
	_action_playing = true
	_anim.play(clip, 0.05)
	_anim.seek(0.0, true)
	return true

func _has_anim(clip: StringName) -> bool:
	return _anim != null and clip != &"" and _anim.has_animation(clip)

func _on_animation_finished(clip: StringName) -> void:
	if _data != null and clip == _data.anim_die:
		return
	_action_playing = false

func _on_hurtbox_body_entered(body: Node3D) -> void:
	if _is_dead or not body.is_in_group("enemy"):
		return
	# push away horizontally from the enemy; straight back if we're right on top of it
	var away: Vector3 = global_position - body.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = -get_facing()
	away = away.normalized()
	velocity = Vector3(away.x * knockback_speed, knockback_lift, away.z * knockback_speed)
	_knockback_left = knockback_time
	health.take_damage(1)

func _on_health_changed(current: int, _max_hp: int) -> void:
	if current < _last_hp:
		hurt_sfx.play()
		if current > 0 and _data != null:
			_play_action(_data.anim_hit)
	_last_hp = current

func _on_died() -> void:
	_is_dead = true
	if _data != null and not _play_action(_data.anim_die):
		_action_playing = true
