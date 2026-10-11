class_name Potion
extends Hazard

@export var heal_amount: int = 1
@export var pickup_sound: AudioStream

func _ready() -> void:
	super._ready()

func _on_hit_player(health: Health) -> void:
	health.heal(heal_amount)
	Sfx.play(pickup_sound, self)
	queue_free()
