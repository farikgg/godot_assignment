extends Node3D
## Sword in the hero's right hand: cooldown, attack animation, Slash hitbox.

## Blade of weapon-sword.glb from the guard to the tip, model units.
const BLADE_LENGTH: float = 0.348
## Middle of the grip below the guard, model units.
const GRIP_Y: float = -0.05

@export var cooldown: float = 0.5
@export_file("*.ogg", "*.wav") var swing_sound_path: String = "res://assets/audio/swing.ogg"
@export var slash_scene: PackedScene
## Hitbox centre in front of the hero, metres.
@export var slash_distance: float = 0.9
## Blade length as a fraction of the hero's arm length.
@export var blade_to_arm_ratio: float = 0.65
## Where the grip sits along the arm, as a fraction of arm_length from the shoulder.
@export var grip_along_arm: float = 0.9
@export var swing_arc_degrees: float = 75.0
@export var swing_time: float = 0.12

@onready var _player: CharacterBody3D = get_parent() as CharacterBody3D
@onready var _pivot: Node3D = $Pivot
@onready var _model: Node3D = $Pivot/Model
@onready var _swing_sfx: AudioStreamPlayer = $SwingSfx

var _last_attack_ms: int = -1_000_000
var _tween: Tween

func _ready() -> void:
	assert(_player != null, "Sword must be a child of the player CharacterBody3D")
	if slash_scene == null:
		push_error("Sword: slash_scene is not set")
	_swing_sfx.stream = Sfx.load_stream(swing_sound_path)
	# the player builds its model in its own _ready, which runs after ours
	_attach_to_hand.call_deferred()

func _attach_to_hand() -> void:
	var socket: Node3D = _player.call("get_hand_socket")
	var data: CharacterData = _player.call("get_character_data")
	var arm: float = data.arm_length if data != null else 0.28
	var scale_factor: float = blade_to_arm_ratio * arm / BLADE_LENGTH
	_pivot.reparent(socket, false)
	# grip in the hand at the end of the arm (-X of the bone), blade pointing forward (+Z)
	_pivot.transform = Transform3D(Basis(), Vector3(-arm * grip_along_arm, 0.0, 0.0))
	var blade_forward := Basis(Vector3.RIGHT, deg_to_rad(90.0))
	_model.transform = Transform3D(blade_forward.scaled(Vector3.ONE * scale_factor),
		blade_forward * Vector3(0.0, -GRIP_Y * scale_factor, 0.0))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack", false):
		if try_attack():
			get_viewport().set_input_as_handled()

func try_attack() -> bool:
	var health: Health = _player.get_node_or_null("Health") as Health
	if health != null and health.is_dead():
		return false
	var now: int = Time.get_ticks_msec()
	if now - _last_attack_ms < int(cooldown * 1000.0):
		return false
	_last_attack_ms = now
	if not _player.call("play_attack"):
		_play_swing_tween()
	_spawn_slash()
	_swing_sfx.play()
	return true

# fallback when the hero has no attack clip
func _play_swing_tween() -> void:
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
	var facing: Vector3 = _player.call("get_facing")
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else _player.get_parent()
	parent.add_child(slash)
	slash.global_transform = Transform3D(Basis.looking_at(facing, Vector3.UP),
		_player.global_position + Vector3(0.0, 0.5, 0.0) + facing * slash_distance)
