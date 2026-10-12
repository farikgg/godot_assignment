class_name CharacterRoster
extends Resource

@export var characters: Array[CharacterData] = []

func first() -> CharacterData:
	if characters.is_empty():
		push_error("CharacterRoster: no characters")
		return null
	return characters[0]

func get_by_id(id: StringName) -> CharacterData:
	for character in characters:
		if character != null and character.id == id:
			return character
	push_warning("CharacterRoster: unknown character id '%s', using the first one" % id)
	return first()

func index_of(id: StringName) -> int:
	for i in characters.size():
		if characters[i] != null and characters[i].id == id:
			return i
	return -1
