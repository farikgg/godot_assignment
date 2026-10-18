class_name TouchActionButton
extends Control
## On-screen button that presses an input action (Unity On-Screen Button):
## it sends InputEventAction pressed / released, so the game treats it like a key.

const NO_POINTER: int = -2
const MOUSE_POINTER: int = -1
const PRESSED_SCALE: float = 0.92

@export var action: StringName
## Button shape (Kenney Mobile Controls).
@export var background: Texture2D
## Purple outline shown while pressed (Kenney Mobile Controls / Highlights).
@export var highlight: Texture2D
## Optional glyph drawn on top of the shape.
@export var icon: Texture2D
## Text on the button when the sprite pack has no icon for this role.
@export var caption: String = ""

@onready var _background: TextureRect = $Background
@onready var _highlight: TextureRect = $Highlight
@onready var _icon: TextureRect = $Icon
@onready var _caption: Label = $Caption

var _pointer: int = NO_POINTER
var _read_mouse: bool = false

func _ready() -> void:
	if action == &"" or not InputMap.has_action(action):
		push_error("TouchActionButton %s: unknown action '%s'" % [name, action])
	_read_mouse = not ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false)
	_background.texture = background
	_highlight.texture = highlight
	_highlight.visible = false
	_icon.texture = icon
	_icon.visible = icon != null
	_caption.text = caption
	_caption.visible = not caption.is_empty()
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and _pointer == NO_POINTER and _hit(touch.position):
			_press(touch.index)
		elif not touch.pressed and touch.index == _pointer:
			_release()
		else:
			return
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if not VirtualStick.is_primary_click(button):
			return
		if not _read_mouse:
			if _hit(button.position) or _pointer != NO_POINTER:
				get_viewport().set_input_as_handled()
			return
		if button.pressed and _pointer == NO_POINTER and _hit(button.position):
			_press(MOUSE_POINTER)
		elif not button.pressed and _pointer == MOUSE_POINTER:
			_release()
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()

func is_pressed() -> bool:
	return _pointer != NO_POINTER

func _hit(point: Vector2) -> bool:
	return is_visible_in_tree() and get_global_rect().has_point(point)

func _press(pointer: int) -> void:
	_pointer = pointer
	_highlight.visible = true
	scale = Vector2.ONE * PRESSED_SCALE
	_send(true)

func _release() -> void:
	_pointer = NO_POINTER
	_highlight.visible = false
	scale = Vector2.ONE
	_send(false)

func _send(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
