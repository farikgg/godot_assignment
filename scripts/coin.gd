extends Area3D

# spin and bob live in the spin_bob clip of the AnimationPlayer
signal collected(value: int)

## Gold this coin is worth (resources/pickups/coin.tres).
@export var data: PickupData
@export var pickup_sound: AudioStream

var _taken: bool = false

func _ready() -> void:
	add_to_group("coins")
	if data == null:
		push_error("Coin %s: no PickupData, it is worth nothing" % name)

## Gold added to the score when collected.
func get_value() -> int:
	return data.value if data != null else 0

func _on_body_entered(body: Node3D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	collected.emit(get_value())
	GameEventBus.get_bus().pickup_collected.emit(global_position, GameEventBus.PICKUP_COIN)
	Sfx.play(pickup_sound, self)
	queue_free()
