class_name Rock
extends Hazard

@export var damage: int = 1

func _ready() -> void:
	super._ready()

func _on_hit_player(health: Health) -> void:
	health.take_damage(damage)
	queue_free()
