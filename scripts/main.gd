extends Node3D

const MESSAGE_DURATION: float = 2.0
const WIN_TEXT: String = "Ты выбрался на свет!"
const GATE_OPEN_TEXT: String = "Решётка поднялась. Путь свободен"
const GATE_CLOSED_TEXT: String = "Решётка опущена. Продержись, пока не стихнет обвал"
const GAME_OVER_TEXT: String = "Тьма поглотила тебя…"
const GOLD_TEXT: String = "Золото: %d / %d"
const CAVE_IN_TEXT: String = "Обвал стихнет через %d"
const KEY_YES_TEXT: String = "Ключ: есть"
const KEY_NO_TEXT: String = "Ключ: нет"
const RESTART_DELAY: float = 1.5
const SURVIVAL_TIME: float = 60.0
const HEART_FULL: Texture2D = preload("res://assets/ui_gen/heart_full.png")
const HEART_EMPTY: Texture2D = preload("res://assets/ui_gen/heart_empty.png")

@export_file("*.ogg", "*.wav") var pickup_sound_path: String = "res://assets/audio/pickup.ogg"

@onready var coin_label: Label = %CoinLabel
@onready var name_label: Label = %NameLabel
@onready var key_label: Label = %KeyLabel
@onready var message_label: Label = %MessageLabel
@onready var hearts_box: HBoxContainer = %HeartsBox
@onready var survival_label: Label = %SurvivalLabel
@onready var pickup_sfx: AudioStreamPlayer = $PickupSfx

var coins_collected: int = 0
var coins_total: int = 0
var has_key: bool = false
var _has_won: bool = false
var _game_over: bool = false
var _message_timer: Timer
var _survival_timer: Timer

func _ready() -> void:
	name_label.text = Profile.player_name
	pickup_sfx.stream = Sfx.load_stream(pickup_sound_path)

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

	# one-shot Timer: stops counting while the tree is paused
	_survival_timer = Timer.new()
	_survival_timer.one_shot = true
	_survival_timer.wait_time = SURVIVAL_TIME
	_survival_timer.timeout.connect(_on_survived)
	add_child(_survival_timer)
	_survival_timer.start()

	_set_message("")
	_update_label()
	_update_key_label()
	_update_survival_label()

func _process(_delta: float) -> void:
	_update_survival_label()

func _on_coin_collected() -> void:
	coins_collected += 1
	_update_label()
	pickup_sfx.play()

func _on_key_collected() -> void:
	has_key = true
	_update_key_label()
	pickup_sfx.play()
	get_tree().call_group("locked_gate", "open")
	_show_message(GATE_OPEN_TEXT)

func _on_gate_hint_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not has_key and not _has_won:
		_show_message(GATE_CLOSED_TEXT)

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
	_survival_timer.paused = true
	_set_message(GAME_OVER_TEXT)
	# process_always = false: the countdown waits while the game is paused
	await get_tree().create_timer(RESTART_DELAY, false).timeout
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_survived() -> void:
	if _game_over or _has_won:
		return
	get_tree().call_group("locked_gate", "open")
	_show_message(GATE_OPEN_TEXT)

func _update_survival_label() -> void:
	var left: int = ceili(_survival_timer.time_left) if not _survival_timer.is_stopped() else 0
	survival_label.text = CAVE_IN_TEXT % left

func _on_exit_reached() -> void:
	# after a win the exit is inert, so re-entering can't print or reset the message
	if _has_won or _game_over:
		return
	_has_won = true
	_message_timer.stop()
	_survival_timer.paused = true
	print("You win!")
	_set_message(WIN_TEXT)

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
		coin_label.text = GOLD_TEXT % [coins_collected, coins_total]

func _update_key_label() -> void:
	if key_label != null:
		key_label.text = KEY_YES_TEXT if has_key else KEY_NO_TEXT
