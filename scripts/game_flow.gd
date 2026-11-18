extends Node
## Autoload GameFlow: moves between the menu, the levels and the win screen (Unity SceneManager).
## The levels come from resources/level_catalog.tres; which ones are open is SaveGame's.

const CATALOG_PATH: String = "res://resources/level_catalog.tres"
const MENU_SCENE: String = "res://scenes/main_menu.tscn"
const WIN_SCENE: String = "res://scenes/win_screen.tscn"
## Real time the audio thread gets to release the stopped music before the engine quits
## (frame counts are unreliable: headless frames run far faster than the audio mix).
const QUIT_DELAY: float = 0.15

var catalog: LevelCatalog
## Index into catalog.levels of the level being played; -1 outside a level.
var current_index: int = -1
## Gold banked over the run: a level's coins count once it is completed.
var total_coins: int = 0
## True while the run started at a first level, so its total counts for SaveGame.best_total.
var run_from_start: bool = false
var _quitting: bool = false

# _init, not _ready: SaveGame (a later autoload) reads the level ids while it starts
func _init() -> void:
	catalog = load(CATALOG_PATH) as LevelCatalog
	if catalog == null:
		push_error("GameFlow: %s is missing or not a LevelCatalog" % CATALOG_PATH)
		catalog = LevelCatalog.new()
	for problem in catalog.validate():
		push_error("GameFlow: level catalog: %s" % problem)

func _ready() -> void:
	# closing the window goes through quit_game() so the music can stop first
	get_tree().set_auto_accept_quit(false)

func levels() -> Array[LevelData]:
	return catalog.levels

## Level ids used by the save.
func level_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for level in catalog.levels:
		if level != null and level.id != &"":
			ids.append(level.id)
	return ids

func default_unlocked_level_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for level in catalog.levels:
		if level != null and level.unlocked_by_default:
			ids.append(level.id)
	return ids

func get_level(id: StringName) -> LevelData:
	return catalog.get_by_id(id)

## The level being played; null outside a level (or for an F6 scene not in the catalog).
func current_level() -> LevelData:
	if current_index < 0 or current_index >= catalog.levels.size():
		return null
	return catalog.levels[current_index]

func current_level_id() -> StringName:
	var level: LevelData = current_level()
	return level.id if level != null else &""

## True when completing the current level ends the run.
func is_last_level() -> bool:
	var level: LevelData = current_level()
	return level != null and level.next_level_id == &""

## Starts the campaign at its first level.
func start_game() -> Error:
	var first: Array[StringName] = default_unlocked_level_ids()
	if first.is_empty():
		push_error("GameFlow: no level is unlocked by default")
		return ERR_DOES_NOT_EXIST
	return start_level(catalog.index_of_id(first[0]))

## Starts a new run at catalog.levels[index]; refuses a level the save keeps locked.
func start_level(index: int) -> Error:
	if index < 0 or index >= catalog.levels.size() or catalog.levels[index] == null:
		push_error("GameFlow: no level at index %d" % index)
		return ERR_DOES_NOT_EXIST
	var level: LevelData = catalog.levels[index]
	if not SaveGame.is_level_unlocked(level.id):
		push_warning("GameFlow: level '%s' is locked" % level.id)
		return ERR_UNAUTHORIZED
	current_index = index
	total_coins = 0
	run_from_start = level.unlocked_by_default
	return _change_scene(level.scene_path)

## Banks `coins` from the finished level and loads its next_level_id, or the win screen.
## The result itself (records, unlock) is recorded by the level through SaveGame.
func next_level(coins: int = 0) -> Error:
	var level: LevelData = current_level()
	if level == null or level.next_level_id == &"":
		return go_to_win(coins)
	var next_index: int = catalog.index_of_id(level.next_level_id)
	if next_index == -1:
		push_error("GameFlow: next level '%s' of '%s' is not in the catalog" % [level.next_level_id, level.id])
		return go_to_win(coins)
	total_coins += maxi(coins, 0)
	current_index = next_index
	return _change_scene(catalog.levels[next_index].scene_path)

func restart_level() -> Error:
	var level: LevelData = current_level()
	if level == null:
		push_error("GameFlow: no current level to restart (index %d)" % current_index)
		return ERR_DOES_NOT_EXIST
	return _change_scene(level.scene_path)

## Opens the win screen; `coins` are the gold of the level just finished (the boss arena).
func go_to_win(coins: int = 0) -> Error:
	total_coins += maxi(coins, 0)
	if run_from_start:
		SaveGame.record_run_total(total_coins)
	run_from_start = false
	current_index = -1
	return _change_scene(WIN_SCENE)

func go_to_menu() -> Error:
	current_index = -1
	run_from_start = false
	return _change_scene(MENU_SCENE)

## Quits the game cleanly: music and every sound still playing are stopped and the audio thread
## gets QUIT_DELAY to release them, otherwise their playbacks leak at exit. Also used for closing
## the window, and by the headless tests (with their exit code).
func quit_game(exit_code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	# also the WM_CLOSE_REQUEST path: closing the window comes through here
	SaveGame.save_game()
	# frozen while the audio thread catches up, so the game can't start new sounds meanwhile
	get_tree().paused = true
	MusicPlayer.stop_all()
	for node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	await get_tree().create_timer(QUIT_DELAY, true, false, true).timeout
	get_tree().quit(exit_code)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

## A level opened straight from the editor (F6) registers itself, so restart / next still work.
## A level already started through start_level / next_level keeps its run state.
func register_level(scene_path: String) -> void:
	var index: int = catalog.index_of_scene(scene_path)
	if index != -1:
		current_index = index

func _change_scene(path: String) -> Error:
	# a scene loaded while the tree is paused would start frozen
	get_tree().paused = false
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("GameFlow: cannot load %s (%s)" % [path, error_string(error)])
	return error
