class_name VirtualStick
extends Control
## On-screen stick that emulates the gamepad's left stick (Unity On-Screen Stick):
## it sends InputEventJoypadMotion on axes 0 / 1, so the game sees it as one more device.

## Device id of the emulated pad; real pads start at 0, so the virtual one never clashes.
const VIRTUAL_DEVICE: int = 8
const MOUSE_POINTER: int = -1
const NO_POINTER: int = -2

## How far the knob may travel from the centre, in pixels; full tilt = 1.0 on the axis.
@export var max_radius: float = 110.0

@onready var _pad: TextureRect = $Pad
@onready var _highlight: TextureRect = $Highlight
@onready var _knob: TextureRect = $Knob

var _pointer: int = NO_POINTER
var _value: Vector2 = Vector2.ZERO
# with mouse->touch emulation on, the mouse already arrives as touch index 0
var _read_mouse: bool = false

func _ready() -> void:
	_read_mouse = not ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false)
	_highlight.visible = false
	_center_knob()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and _pointer == NO_POINTER and _hit(touch.position):
			_grab(touch.index, touch.position)
		elif not touch.pressed and touch.index == _pointer:
			_release()
		else:
			return
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index != _pointer:
			return
		_follow(drag.position)
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if not is_primary_click(button):
			return
		if not _read_mouse:
			# the emulated touch handles it; just keep the click from becoming an attack
			if _hit(button.position) or _pointer != NO_POINTER:
				get_viewport().set_input_as_handled()
			return
		if button.pressed and _pointer == NO_POINTER and _hit(button.position):
			_grab(MOUSE_POINTER, button.position)
		elif not button.pressed and _pointer == MOUSE_POINTER:
			_release()
		else:
			return
	elif event is InputEventMouseMotion:
		if not _read_mouse or _pointer != MOUSE_POINTER:
			return
		_follow((event as InputEventMouseMotion).position)
	else:
		return
	# same as accept_event() for a Control: the touch must not reach the game as an attack
	get_viewport().set_input_as_handled()

## Primary (left) mouse button event; the one place that names a mouse button, shared with
## TouchActionButton so game code never refers to raw buttons.
static func is_primary_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT

## Current stick value, -1..1 on both axes (y down = back).
func value() -> Vector2:
	return _value

func _hit(point: Vector2) -> bool:
	return is_visible_in_tree() and get_global_rect().has_point(point)

func _grab(pointer: int, at: Vector2) -> void:
	_pointer = pointer
	_highlight.visible = true
	_follow(at)

func _follow(at: Vector2) -> void:
	var offset: Vector2 = (at - get_global_rect().get_center()).limit_length(max_radius)
	_knob.position = size * 0.5 + offset - _knob.size * 0.5
	_send(offset / max_radius)

func _release() -> void:
	_pointer = NO_POINTER
	_highlight.visible = false
	_center_knob()
	_send(Vector2.ZERO)

func _center_knob() -> void:
	_knob.position = (size - _knob.size) * 0.5

func _send(stick: Vector2) -> void:
	_value = stick
	_emit_axis(JOY_AXIS_LEFT_X, stick.x)
	_emit_axis(JOY_AXIS_LEFT_Y, stick.y)

func _emit_axis(axis: JoyAxis, axis_value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.device = VIRTUAL_DEVICE
	motion.axis = axis
	motion.axis_value = axis_value
	Input.parse_input_event(motion)
