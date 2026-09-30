extends Area3D

signal reached

func _on_body_entered(body: Node3D) -> void:
	if body != null and body.is_in_group("player"):
		reached.emit()
