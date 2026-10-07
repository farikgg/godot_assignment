extends Area3D

# spin and bob live in the spin_bob clip, like on the coin
signal collected

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		collected.emit()
		queue_free()
