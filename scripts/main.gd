extends Node3D

const MESSAGE_DURATION: float = 2.0
const WIN_TEXT: String = "Победа!\nМонеты: %d / %d"
const KEY_FOUND_TEXT: String = "Ключ найден! Путь открыт"
const NEED_KEY_TEXT: String = "Нужен ключ"
const GAME_OVER_TEXT: String = "Game over"
const RESTART_DELAY: float = 1.5
const HEART_FULL: Texture2D = preload("res://assets/ui_gen/heart_full.png")
const HEART_EMPTY: Texture2D = preload("res://assets/ui_gen/heart_empty.png")

@onready var coin_label: Label = %CoinLabel
@onready var name_label: Label = %NameLabel
@onready var key_label: Label = %KeyLabel
@onready var message_label: Label = %MessageLabel
@onready var hearts_box: HBoxContainer = %HeartsBox

var coins_collected: int = 0
var coins_total: int = 0
var has_key: bool = false
var _has_won: bool = false
var _game_over: bool = false
var _message_timer: Timer

func _ready() -> void:
	name_label.text = Profile.player_name

	var coins: Array[Node] = get_tree().get_nodes_in_group("coins")
	coins_total = coins.size()
	for coin in coins:
		if coin.has_signal("collected"):
			coin.connect("collected", _on_coin_collected)

	for key in get_tree().get_nodes_in_group("key"):
		if key.has_signal("collected"):
			key.connect("collected", _on_key_collected)

	for exit_node in get_tree().get_nodes_in_group("exit"):
		if exit_node.has_signal("reached") and not exit_node.is_connected("reached", _on_exit_reached):
			exit_node.connect("reached", _on_exit_reached)

	for hint in get_tree().get_nodes_in_group("gate_hint"):
		if hint is Area3D:
			(hint as Area3D).body_entered.connect(_on_gate_hint_body_entered)

	var health: Health = _find_player_health()
	if health != null:
		health.changed.connect(_on_health_changed)
		health.died.connect(_on_player_died)
		_on_health_changed(health.current, health.max_hp)

	_message_timer = Timer.new()
	_message_timer.one_shot = true
	_message_timer.timeout.connect(_on_message_timeout)
	add_child(_message_timer)

	_set_message("")
	_update_label()
	_update_key_label()

func _on_coin_collected() -> void:
	coins_collected += 1
	_update_label()

func _on_key_collected() -> void:
	has_key = true
	_update_key_label()
	get_tree().call_group("locked_gate", "open")
	_show_message(KEY_FOUND_TEXT)

func _on_gate_hint_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not has_key and not _has_won:
		_show_message(NEED_KEY_TEXT)

func _find_player_health() -> Health:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("Main: no node in group \"player\"")
		return null
	var health: Health = player.get_node_or_null("Health") as Health
	if health == null:
		push_error("Main: player has no Health child")
	return health

func _on_health_changed(current: int, max_hp: int) -> void:
	var hearts: Array[Node] = hearts_box.get_children()
	if hearts.size() != max_hp:
		push_error("Main: HeartsBox has %d icons for max_hp %d" % [hearts.size(), max_hp])
	for i in hearts.size():
		var icon: TextureRect = hearts[i] as TextureRect
		if icon != null:
			icon.texture = HEART_FULL if i < current else HEART_EMPTY

func _on_player_died() -> void:
	if _game_over or _has_won:
		return
	_game_over = true
	_message_timer.stop()
	_set_message(GAME_OVER_TEXT)
	# process_always = false: the countdown waits while the game is paused
	await get_tree().create_timer(RESTART_DELAY, false).timeout
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_exit_reached() -> void:
	# after a win the exit is inert, so re-entering can't print or reset the message
	if _has_won or _game_over:
		return
	_has_won = true
	_message_timer.stop()
	print("You win!")
	_set_message(WIN_TEXT % [coins_collected, coins_total])

func _show_message(text: String) -> void:
	_set_message(text)
	_message_timer.start(MESSAGE_DURATION)

func _on_message_timeout() -> void:
	if not _has_won and not _game_over:
		_set_message("")

func _set_message(text: String) -> void:
	if message_label != null:
		message_label.text = text

func _update_label() -> void:
	if coin_label != null:
		coin_label.text = "Монеты: %d / %d" % [coins_collected, coins_total]

func _update_key_label() -> void:
	if key_label != null:
		key_label.text = "Ключ: есть" if has_key else "Ключ: нет"
