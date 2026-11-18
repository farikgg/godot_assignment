class_name Level
extends Node3D
## Shared logic of every level: spawns its enemies and cave-in from the LevelData, gold, key and
## gate, HUD, exit (or boss) to the next level, death and restart.

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
const NEED_GOLD_TEXT: String = "Нужно больше золота: %d / %d"
const SPAWNER_SCENE: PackedScene = preload("res://scenes/systems/spawner.tscn")
## Spawned enemies go under this node when the scene has it (level 1 bakes navigation from it).
const ENEMIES_NODE: NodePath = ^"Enemies"

## Played when the exit is reached and when the boss falls.
@export var win_sound: AudioStream

@onready var hud: Hud = $HUD

var coins_collected: int = 0
var coins_total: int = 0
var has_key: bool = false
var _has_won: bool = false
var _game_over: bool = false
## Seconds played in this attempt; stops at the win and while the game is paused.
var elapsed_sec: float = 0.0
## This level's LevelData; null for a scene that is not in the catalog (nothing is spawned).
var data: LevelData

func _ready() -> void:
	assert(hud != null, "Level needs a HUD instance (scenes/ui/hud.tscn)")
	GameFlow.register_level(scene_file_path)
	data = GameFlow.current_level()
	if data == null:
		push_warning("Level: %s is not in the level catalog, no enemies are spawned" % scene_file_path)
	else:
		_spawn_content()
	MusicPlayer.play_level(data != null and data.goal == LevelData.Goal.BOSS)
	hud.set_player_name(Profile.player_name)

	# the score is gold, not coins: each coin is worth its PickupData.value
	for coin in get_tree().get_nodes_in_group("coins"):
		if coin.has_signal("collected") and coin.has_method("get_value"):
			coins_total += coin.call("get_value") as int
			coin.connect("collected", _on_coin_collected)
	if data != null and data.goal == LevelData.Goal.EXIT and data.coins_required > coins_total:
		push_error("Level %s: coins_required %d but the coins are worth %d, the exit can never open"
			% [data.id, data.coins_required, coins_total])

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
	# the title lives in the level's LevelData (resources/levels/)
	if data != null and not data.title.is_empty():
		hud.show_message(data.title, TITLE_DURATION)

# --- spawning from LevelData ----------------------------------------------------------------

func _spawn_content() -> void:
	var parent: Node3D = get_node_or_null(ENEMIES_NODE) as Node3D
	if parent == null:
		parent = self
	for spawn in data.enemy_spawns:
		if spawn != null:
			_spawn_enemy(spawn, parent)
	if data.spawner != null:
		_spawn_cave_in()
	# a goal the scene cannot satisfy would leave the level unwinnable: say so loudly
	match data.goal:
		LevelData.Goal.BOSS:
			if get_tree().get_nodes_in_group("boss").is_empty():
				push_error("Level %s: goal BOSS, but no boss was spawned" % data.id)
		LevelData.Goal.EXIT:
			if get_tree().get_nodes_in_group("exit").is_empty():
				push_error("Level %s: goal EXIT, but the scene has no exit" % data.id)

func _spawn_enemy(spawn: EnemySpawn, parent: Node3D) -> void:
	var problems: PackedStringArray = spawn.validate()
	var marker: Marker3D = _find_marker(spawn.marker)
	if marker == null:
		problems.append("no Marker3D named '%s' in the scene" % spawn.marker)
	if not problems.is_empty():
		push_error("Level %s: enemy spawn skipped: %s" % [data.id, ", ".join(problems)])
		return
	var node: Node = spawn.scene.instantiate()
	var enemy: Enemy = node as Enemy
	if enemy == null:
		push_error("Level %s: %s is not an Enemy, skipped" % [data.id, spawn.scene.resource_path])
		node.free()
		return
	# set before add_child: the enemy reads them in its _ready
	enemy.data = spawn.data
	enemy.start_yaw_degrees = spawn.start_yaw_degrees
	if enemy is Minion:
		(enemy as Minion).patrol_offset = spawn.patrol_offset
	enemy.position = parent.to_local(marker.global_position)
	parent.add_child(enemy, true)

func _spawn_cave_in() -> void:
	var marker: Marker3D = _find_marker(data.spawner_marker)
	if marker == null:
		push_error("Level %s: no Marker3D named '%s' for the cave-in" % [data.id, data.spawner_marker])
		return
	var spawner: Node3D = SPAWNER_SCENE.instantiate() as Node3D
	spawner.set(&"data", data.spawner)
	spawner.position = to_local(marker.global_position)
	add_child(spawner, true)

func _find_marker(marker_name: StringName) -> Marker3D:
	if marker_name == &"":
		return null
	var found: Array[Node] = find_children(String(marker_name), "Marker3D", true, false)
	return found[0] as Marker3D if not found.is_empty() else null

func _process(delta: float) -> void:
	if not _has_won and not _game_over:
		elapsed_sec += delta

func _on_coin_collected(value: int) -> void:
	coins_collected += value
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
	Sfx.play(win_sound, self)
	hud.show_message(BOSS_DEFEATED_TEXT)

func _on_boss_defeated() -> void:
	if _game_over:
		return
	_record_result()
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
	var required: int = data.coins_required if data != null else 0
	if coins_collected < required:
		_show_timed(NEED_GOLD_TEXT % [coins_collected, required])
		return
	_has_won = true
	Sfx.play(win_sound, self)
	hud.show_message(WIN_TEXT if GameFlow.is_last_level() else LEVEL_DONE_TEXT)
	await get_tree().create_timer(EXIT_DELAY, false).timeout
	_record_result()
	GameFlow.next_level(coins_collected)

# a level opened with F6 that is not in GameFlow's list has no id and records nothing
func _record_result() -> void:
	var level_id: StringName = GameFlow.current_level_id()
	if level_id != &"":
		SaveGame.record_level_result(level_id, coins_collected, elapsed_sec)

## Short hint toast for props (e.g. «Здоровье полное» from a potion).
func show_hint(text: String) -> void:
	_show_timed(text)

# short-lived hint; never covers the exit / game-over text
func _show_timed(text: String) -> void:
	if not _has_won and not _game_over:
		hud.show_message(text, MESSAGE_DURATION)
