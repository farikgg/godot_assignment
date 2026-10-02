extends Label

# keep in sync with application/config/name in project.godot
const GAME_TITLE: String = "Dungeon Roller"

func _ready() -> void:
	text = GAME_TITLE
