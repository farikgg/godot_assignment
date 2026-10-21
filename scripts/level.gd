class_name Level
extends Node3D
## Shared logic of every level: gold, key and gate, HUD, exit to the next level, death and restart.

const MESSAGE_DURATION: float = 2.0
const TITLE_DURATION: float = 2.5
const LEVEL_DONE_TEXT: String = "Уровень пройден!"
const WIN_TEXT: String = "Ты выбрался на свет!"
const GATE_OPEN_TEXT: String = "Решётка поднялась. Путь свободен"
const GATE_CLOSED_TEXT: String = "Решётка опущена. Найди ключ"
const GAME_OVER_TEXT: String = "Тьма поглотила тебя…"
const SWORD_FOUND_TEXT: String = "Меч найден. J, X или ЛКМ — удар"
const SWORD_HINT_DURATION: float = 3.0
const RESTART_DELAY: float = 1.5
## Pause between reaching the exit and loading the next level, so the toast can be read.
const EXIT_DELAY: float = 1.5
const BOSS_AWAKE_TEXT: String = "Страж подземелья пробудился"
const BOSS_ENRAGED_TEXT: String = "Страж в ярости!"
const BOSS_DEFEATED_TEXT: String = "Страж повержен!"

## Shown as a toast when the level starts, e.g. «Уровень 1 — Верхние залы».
@export var level_title: String = ""
## Played when the exit is reached and when the boss falls.
@export_file("*.ogg", "*.wav") var win_sound_path: String = "res://assets/Audio/sfx/win.wav"

@onready var hud: Hud = $HUD

var coins_collected: int = 0
var coins_total: int = 0
var has_key: bool = false
var _has_won: bool = false
var _game_over: bool = false
var _win_sound: AudioStream

func _ready() -> void:
	assert(hud != null, "Level needs a HUD instance (scenes/ui/hud.tscn)")
	GameFlow.register_level(scene_file_path)
	MusicPlayer.play_level(not get_tree().get_nodes_in_group("boss").is_empty())
	_win_sound = Sfx.load_stream(win_sound_path)
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

	for boss in get_tree().get_nodes_in_group("boss"):
		_connect_boss(boss as Boss)

	hud.set_coins(coins_collected, coins_total)
	hud.set_key(has_key)
	if not level_title.is_empty():
		hud.show_message(level_title, TITLE_DURATION)

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
		push_error("Level: no node in group \"player\"")
		return null
	var health: Health = player.get_node_or_null("Health") as Health
	if health == null:
		push_error("Level: player has no Health child")
	return health

# the arena: HP bar on the HUD, toasts for the phases, the win screen after the defeat
func _connect_boss(boss: Boss) -> void:
	if boss == null:
		return
	hud.show_boss_bar(Boss.DISPLAY_NAME, boss.health.current, boss.health.max_hp)
	boss.health.changed.connect(hud.set_boss_hp)
	boss.awakened.connect(_show_timed.bind(BOSS_AWAKE_TEXT))
	boss.enraged.connect(_show_timed.bind(BOSS_ENRAGED_TEXT))
	boss.died.connect(_on_boss_died)
	boss.defeated.connect(_on_boss_defeated)

func _on_boss_died() -> void:
	if _game_over:
		return
	# the hero can no longer lose: nothing restarts the level from here
	_has_won = true
	Sfx.play(_win_sound, self)
	hud.show_message(BOSS_DEFEATED_TEXT)

func _on_boss_defeated() -> void:
	if _game_over:
		return
	GameFlow.go_to_win(coins_collected)

func _on_player_died() -> void:
	if _game_over or _has_won:
		return
	_game_over = true
	hud.show_message(GAME_OVER_TEXT)
	# process_always = false: the countdown waits while the game is paused
	await get_tree().create_timer(RESTART_DELAY, false).timeout
	GameFlow.restart_level()

func _on_exit_reached() -> void:
	# after the exit is reached it is inert, so re-entering can't trigger the move twice
	if _has_won or _game_over:
		return
	_has_won = true
	Sfx.play(_win_sound, self)
	var last: bool = GameFlow.current_index >= GameFlow.LEVELS.size() - 1
	hud.show_message(WIN_TEXT if last else LEVEL_DONE_TEXT)
	await get_tree().create_timer(EXIT_DELAY, false).timeout
	GameFlow.next_level(coins_collected)

## Short hint toast for props (e.g. «Здоровье полное» from a potion).
func show_hint(text: String) -> void:
	_show_timed(text)

# short-lived hint; never covers the exit / game-over text
func _show_timed(text: String) -> void:
	if not _has_won and not _game_over:
		hud.show_message(text, MESSAGE_DURATION)
