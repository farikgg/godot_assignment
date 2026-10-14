class_name Potion
extends Hazard

@export var heal_amount: int = 1
@export_file("*.ogg", "*.wav") var pickup_sound_path: String = ""

var _pickup_sound: AudioStream

func _ready() -> void:
	super._ready()
	_pickup_sound = Sfx.load_stream(pickup_sound_path)

func _on_hit_player(health: Health) -> void:
	health.heal(heal_amount)
	Sfx.play(_pickup_sound, self)
	queue_free()
