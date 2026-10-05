extends Node3D

const HINT_DURATION: float = 2.0
const HINT_TEXT: String = "Collect all coins first!"
const WIN_TEXT: String = "Победа!"

@onready var coin_label: Label = %CoinLabel
@onready var name_label: Label = %NameLabel
@onready var message_label: Label = %MessageLabel

var coins_collected: int = 0
var coins_total: int = 0
var _has_won: bool = false
var _hint_timer: Timer

func _ready() -> void:
	name_label.text = Profile.player_name

	var coins: Array[Node] = get_tree().get_nodes_in_group("coins")
	coins_total = coins.size()
	for coin in coins:
		if coin.has_signal("collected"):
			coin.connect("collected", _on_coin_collected)

	for exit_node in get_tree().get_nodes_in_group("exit"):
		if exit_node.has_signal("reached") and not exit_node.is_connected("reached", _on_exit_reached):
			exit_node.connect("reached", _on_exit_reached)

	_hint_timer = Timer.new()
	_hint_timer.one_shot = true
	_hint_timer.timeout.connect(_on_hint_timeout)
	add_child(_hint_timer)

	_set_message("")
	_update_label()

func _on_coin_collected() -> void:
	coins_collected += 1
	_update_label()
	if coins_collected >= coins_total:
		get_tree().call_group("gate", "open")

func _on_exit_reached() -> void:
	# after a win the exit is inert, so re-entering can't print or reset the message
	if _has_won:
		return
	if coins_collected >= coins_total:
		_has_won = true
		_hint_timer.stop()
		print("You win!")
		_set_message(WIN_TEXT)
	else:
		print(HINT_TEXT)
		_set_message(HINT_TEXT)
		_hint_timer.start(HINT_DURATION)

func _on_hint_timeout() -> void:
	if not _has_won:
		_set_message("")

func _set_message(text: String) -> void:
	if message_label != null:
		message_label.text = text

func _update_label() -> void:
	if coin_label != null:
		coin_label.text = "Монеты: %d / %d" % [coins_collected, coins_total]
