extends Node
## Autoload UiSounds: a click on every Button in any scene, menus and pause included.

@export var click_sound: AudioStream

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(_play_click.bind(node))

func _play_click(button: Node) -> void:
	# the pause menu's buttons work during the pause, so the click must too
	Sfx.play(click_sound, button, true)
