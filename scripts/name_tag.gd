extends Label3D

# The body never rotates (only Visual turns), so a plain child stays above the head.
func _ready() -> void:
	text = Profile.player_name
