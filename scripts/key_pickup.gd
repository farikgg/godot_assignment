extends Area3D

# spin and bob live in the spin_bob clip, like on the coin
signal collected

@export var pickup_sound: AudioStream

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		collected.emit()
		Sfx.play(pickup_sound, self)
		queue_free()
