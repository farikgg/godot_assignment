extends CanvasLayer
## On-screen stick and buttons above the HUD.

## Show on desktop too (needed for the A7 video); on touch devices they are always shown.
@export var show_on_desktop: bool = true

func _ready() -> void:
	# a finger lifted during the pause must still release the stick / button
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = show_on_desktop or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
