extends Node

const SAVE_PATH: String = "user://profile.cfg"
const SECTION: String = "profile"
const DEFAULT_NAME: String = "Player"
## Pre-roster saves stored a ball colour instead of a character.
const LEGACY_COLOR_KEY: String = "ball_color_index"

var player_name: String = DEFAULT_NAME
var character_id: StringName = &""
## Tests point this at a scratch file so the real profile is untouched.
var save_path: String = SAVE_PATH

func _ready() -> void:
	reload()

func set_player_name(value: String) -> void:
	player_name = value
	_save()

func set_character(id: StringName) -> void:
	character_id = id
	_save()

func reload() -> void:
	player_name = DEFAULT_NAME
	character_id = Roster.first().id if Roster.first() != null else &""
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	player_name = config.get_value(SECTION, "player_name", DEFAULT_NAME)
	if config.has_section_key(SECTION, "character_id"):
		character_id = StringName(config.get_value(SECTION, "character_id", ""))
	elif config.has_section_key(SECTION, LEGACY_COLOR_KEY):
		# old save: keep the name, start with the first hero, rewrite in the new format
		_save()

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "player_name", player_name)
	config.set_value(SECTION, "character_id", String(character_id))
	config.save(save_path)
