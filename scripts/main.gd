extends Node3D

const MESSAGE_DURATION: float = 2.0
const WIN_TEXT: String = "Ты выбрался на свет!"
const GATE_OPEN_TEXT: String = "Решётка поднялась. Путь свободен"
const GATE_CLOSED_TEXT: String = "Решётка опущена. Продержись, пока не стихнет обвал"
const GAME_OVER_TEXT: String = "Тьма поглотила тебя…"
const SWORD_FOUND_TEXT: String = "Меч найден. J, X или ЛКМ — удар"
const SWORD_HINT_DURATION: float = 3.0
const RESTART_DELAY: float = 1.5
const SURVIVAL_TIME: float = 60.0

@onready var hud: Hud = $HUD

var coins_collected: int = 0
var coins_total: int = 0
var has_key: bool = false
var _has_won: bool = false
var _game_over: bool = false
var _survival_timer: Timer

func _ready() -> void:
	assert(hud != null, "Main needs a HUD instance (scenes/ui/hud.tscn)")
	hud.set_player_name(Profile.player_name)

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

	for pickup in get_tree().get_nodes_in_group("weapon_pickup"):
		if pickup.has_signal("picked_up"):
			pickup.connect("picked_up", _on_weapon_picked_up)

	for hint in get_tree().get_nodes_in_group("gate_hint"):
		if hint is Area3D:
			(hint as Area3D).body_entered.connect(_on_gate_hint_body_entered)

	var health: Health = _find_player_health()
	if health != null:
		health.changed.connect(hud.set_hearts)
		health.died.connect(_on_player_died)
		hud.set_hearts(health.current, health.max_hp)

	# one-shot Timer: stops counting while the tree is paused
	_survival_timer = Timer.new()
	_survival_timer.one_shot = true
	_survival_timer.wait_time = SURVIVAL_TIME
	_survival_timer.timeout.connect(_on_survived)
	add_child(_survival_timer)
	_survival_timer.start()

	hud.set_coins(coins_collected, coins_total)
	hud.set_key(has_key)
	_update_survival_time()

func _process(_delta: float) -> void:
	_update_survival_time()

func _on_coin_collected() -> void:
	coins_collected += 1
	hud.set_coins(coins_collected, coins_total)

func _on_key_collected() -> void:
	has_key = true
	hud.set_key(true)
	get_tree().call_group("locked_gate", "open")
	_show_timed(GATE_OPEN_TEXT)

func _on_gate_hint_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not has_key and not _has_won:
		_show_timed(GATE_CLOSED_TEXT)

func _on_weapon_picked_up() -> void:
	if not _has_won and not _game_over:
		hud.show_message(SWORD_FOUND_TEXT, SWORD_HINT_DURATION)

func _find_player_health() -> Health:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("Main: no node in group \"player\"")
		return null
	var health: Health = player.get_node_or_null("Health") as Health
	if health == null:
		push_error("Main: player has no Health child")
	return health

func _on_player_died() -> void:
	if _game_over or _has_won:
		return
	_game_over = true
	_survival_timer.paused = true
	hud.show_message(GAME_OVER_TEXT)
	# process_always = false: the countdown waits while the game is paused
	await get_tree().create_timer(RESTART_DELAY, false).timeout
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_survived() -> void:
	if _game_over or _has_won:
		return
	get_tree().call_group("locked_gate", "open")
	_show_timed(GATE_OPEN_TEXT)

func _update_survival_time() -> void:
	hud.set_survival_time(ceili(_survival_timer.time_left) if not _survival_timer.is_stopped() else 0)

func _on_exit_reached() -> void:
	# after a win the exit is inert, so re-entering can't print or reset the message
	if _has_won or _game_over:
		return
	_has_won = true
	_survival_timer.paused = true
	print("You win!")
	hud.show_message(WIN_TEXT)

# short-lived hint; never covers the win / game-over text
func _show_timed(text: String) -> void:
	if not _has_won and not _game_over:
		hud.show_message(text, MESSAGE_DURATION)
