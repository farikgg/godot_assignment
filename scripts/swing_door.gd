extends Node3D

# swing_pos / swing_neg open the door away from the player; closing plays the same clip backwards
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sensor: Area3D = $Sensor

var _clip: StringName = &"swing_pos"

func _ready() -> void:
	sensor.body_entered.connect(_on_sensor_body_entered)
	sensor.body_exited.connect(_on_sensor_body_exited)

func _on_sensor_body_entered(other: Node3D) -> void:
	if not other.is_in_group("player"):
		return
	# pick a side only from fully closed, so re-entering mid-swing never snaps the door
	if _is_closed():
		_clip = &"swing_pos" if to_local(other.global_position).z >= 0.0 else &"swing_neg"
	anim.play(_clip)

func _on_sensor_body_exited(other: Node3D) -> void:
	if other.is_in_group("player"):
		anim.play_backwards(_clip)

func _is_closed() -> bool:
	if anim.assigned_animation == &"":
		return true
	return not anim.is_playing() and is_zero_approx(anim.current_animation_position)
