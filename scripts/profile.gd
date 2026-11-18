extends Node
## Autoload Profile: the hero's name and chosen character. Storage is SaveGame's (user://save.json).

var player_name: String:
	get:
		return SaveGame.player_name
	set(value):
		SaveGame.set_player_name(value)

var character_id: StringName:
	get:
		return SaveGame.selected_hero
	set(value):
		SaveGame.set_selected_hero(value)

func set_player_name(value: String) -> void:
	SaveGame.set_player_name(value)

## False when the hero is unknown or still locked.
func set_character(id: StringName) -> bool:
	return SaveGame.set_selected_hero(id)

func reload() -> void:
	SaveGame.load_game()
