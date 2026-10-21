extends Area3D

# spin and bob live in the spin_bob clip of the AnimationPlayer
signal collected

@export_file("*.ogg", "*.wav") var pickup_sound_path: String = "res://assets/Audio/sfx/coin.wav"

var _pickup_sound: AudioStream

func _ready() -> void:
	_pickup_sound = Sfx.load_stream(pickup_sound_path)
	add_to_group("coins")

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		collected.emit()
		Sfx.play(_pickup_sound, self)
		queue_free()
