extends Node
## Autoload GameFlow: moves between the menu, the levels and the win screen (Unity SceneManager).

const LEVELS: Array[String] = [
	"res://scenes/levels/level_1.tscn",
	"res://scenes/levels/level_2.tscn",
	"res://scenes/levels/level_3_boss.tscn",
]
const MENU_SCENE: String = "res://scenes/main_menu.tscn"
const WIN_SCENE: String = "res://scenes/win_screen.tscn"
## Real time the audio thread gets to release the stopped music before the engine quits
## (frame counts are unreliable: headless frames run far faster than the audio mix).
const QUIT_DELAY: float = 0.15

## Index into LEVELS of the level being played; -1 outside a run.
var current_index: int = -1
## Gold banked over the run: a level's coins count once it is completed.
var total_coins: int = 0
var _quitting: bool = false

func _ready() -> void:
	# closing the window goes through quit_game() so the music can stop first
	get_tree().set_auto_accept_quit(false)

func start_game() -> Error:
	current_index = 0
	total_coins = 0
	return _change_scene(LEVELS[current_index])

## Banks `coins` from the finished level and loads the next one, or the win screen after the last.
func next_level(coins: int = 0) -> Error:
	total_coins += maxi(coins, 0)
	if current_index + 1 >= LEVELS.size():
		return go_to_win()
	current_index = maxi(current_index + 1, 0)
	return _change_scene(LEVELS[current_index])

func restart_level() -> Error:
	if current_index < 0 or current_index >= LEVELS.size():
		push_error("GameFlow: no current level to restart (index %d)" % current_index)
		return ERR_DOES_NOT_EXIST
	return _change_scene(LEVELS[current_index])

## Opens the win screen; `coins` are the gold of the level just finished (the boss arena).
func go_to_win(coins: int = 0) -> Error:
	total_coins += maxi(coins, 0)
	current_index = -1
	return _change_scene(WIN_SCENE)

func go_to_menu() -> Error:
	current_index = -1
	return _change_scene(MENU_SCENE)

## A level opened straight from the editor (F6) registers itself, so restart / next still work.
## Quits the game cleanly: the music is stopped and the audio thread gets a few frames to
## release it, otherwise 8-bit_sound.ogg leaks at exit. Also used for closing the window.
func quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	get_tree().paused = false
	MusicPlayer.stop_all()
	await get_tree().create_timer(QUIT_DELAY, true, false, true).timeout
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func register_level(scene_path: String) -> void:
	var index: int = LEVELS.find(scene_path)
	if index != -1:
		current_index = index

func _change_scene(path: String) -> Error:
	# a scene loaded while the tree is paused would start frozen
	get_tree().paused = false
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("GameFlow: cannot load %s (%s)" % [path, error_string(error)])
	return error
