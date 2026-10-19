extends Node
## Autoload GameFlow: moves between the menu, the levels and the win screen (Unity SceneManager).

const LEVELS: Array[String] = [
	"res://scenes/levels/level_1.tscn",
	"res://scenes/levels/level_2.tscn",
	"res://scenes/levels/level_3_boss.tscn",
]
const MENU_SCENE: String = "res://scenes/main_menu.tscn"
const WIN_SCENE: String = "res://scenes/win_screen.tscn"

## Index into LEVELS of the level being played; -1 outside a run.
var current_index: int = -1
## Gold banked over the run: a level's coins count once it is completed.
var total_coins: int = 0

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

func go_to_win() -> Error:
	current_index = -1
	return _change_scene(WIN_SCENE)

func go_to_menu() -> Error:
	current_index = -1
	return _change_scene(MENU_SCENE)

## A level opened straight from the editor (F6) registers itself, so restart / next still work.
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
