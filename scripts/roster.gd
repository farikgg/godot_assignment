extends Node
## Autoload: the character roster for the menu, the player and the future shop.

const ROSTER_PATH: String = "res://resources/character_roster.tres"

var roster: CharacterRoster

func _init() -> void:
	roster = load(ROSTER_PATH) as CharacterRoster
	if roster == null:
		push_error("Roster: %s is missing or not a CharacterRoster" % ROSTER_PATH)
		roster = CharacterRoster.new()

func all() -> Array[CharacterData]:
	return roster.characters

func first() -> CharacterData:
	return roster.first()

func get_by_id(id: StringName) -> CharacterData:
	return roster.get_by_id(id)
