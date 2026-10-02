extends PanelContainer

# main.gd only writes the label text, so the frame follows it from here
@export var label: Label

func _ready() -> void:
	_sync_visibility()

func _process(_delta: float) -> void:
	_sync_visibility()

func _sync_visibility() -> void:
	visible = label != null and not label.text.is_empty()
