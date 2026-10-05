extends Area3D

# spin and bob live in the spin_bob clip of the AnimationPlayer
signal collected

func _ready() -> void:
	add_to_group("coins")

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		collected.emit()
		queue_free()
