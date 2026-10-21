extends Area3D
## A weapon lying on the floor; the player picks it up by walking into it.

signal picked_up

@export var weapon_scene: PackedScene
@export_file("*.ogg", "*.wav") var pickup_sound_path: String = "res://assets/Audio/sfx/pickup.wav"

var _pickup_sound: AudioStream

func _ready() -> void:
	add_to_group("weapon_pickup")
	_pickup_sound = Sfx.load_stream(pickup_sound_path)
	if weapon_scene == null:
		push_error("SwordPickup: weapon_scene is not set")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if weapon_scene == null or not body.is_in_group("player"):
		return
	if not body.has_method("equip_weapon"):
		push_error("SwordPickup: %s has no equip_weapon()" % body.name)
		return
	body.call("equip_weapon", weapon_scene)
	Sfx.play(_pickup_sound, self)
	picked_up.emit()
	queue_free()
