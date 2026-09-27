extends Node3D

@onready var coin_label: Label = $UI/CoinLabel
@onready var name_label: Label = $UI/NameLabel

var coins_collected: int = 0

func _ready() -> void:
	name_label.text = Profile.player_name
	for coin in get_tree().get_nodes_in_group("coins"):
		coin.collected.connect(_on_coin_collected)
	_update_label()

func _on_coin_collected() -> void:
	coins_collected += 1
	_update_label()

func _update_label() -> void:
	coin_label.text = "Монеты: %d" % coins_collected
