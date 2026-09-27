extends Node

const SAVE_PATH := "user://profile.cfg"

var player_name: String = "Player"
var ball_color_index: int = 0

func _ready() -> void:
	_load()

func set_player_name(value: String) -> void:
	player_name = value
	_save()

func set_ball_color(index: int) -> void:
	ball_color_index = index
	_save()

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "player_name", player_name)
	config.set_value("profile", "ball_color_index", ball_color_index)
	config.save(SAVE_PATH)

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		player_name = config.get_value("profile", "player_name", "Player")
		ball_color_index = config.get_value("profile", "ball_color_index", 0)
