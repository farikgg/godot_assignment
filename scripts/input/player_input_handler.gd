class_name PlayerInputHandler
extends Node
## Turns input events into a move vector and jump / attack signals (Unity PlayerInput + Send Messages).
## Keyboard, gamepad and the on-screen controls all arrive as events, so they are handled the same way.

signal jump_pressed
signal attack_pressed

const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const MOVE_FORWARD: StringName = &"move_forward"
const MOVE_BACK: StringName = &"move_back"
const MOVE_ACTIONS: Array[StringName] = [MOVE_LEFT, MOVE_RIGHT, MOVE_FORWARD, MOVE_BACK]

## Movement on the ground plane: x = right, y = back; length 0..1. Read-only from outside.
var move: Vector2:
	get:
		return _move
	set(_value):
		push_error("PlayerInputHandler.move is read-only")

var _move: Vector2 = Vector2.ZERO
# action -> {source -> strength}; one entry per device type so a stick at rest
# doesn't cancel a key that is still held for the same action
var _strengths: Dictionary = {}

func _ready() -> void:
	# keep tracking releases while paused, or a key let go during the pause would stick
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in MOVE_ACTIONS:
		_strengths[action] = {}

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_all()

func _unhandled_input(event: InputEvent) -> void:
	var changed: bool = false
	for action in MOVE_ACTIONS:
		if event.is_action(action):
			(_strengths[action] as Dictionary)[_source_of(event)] = event.get_action_strength(action)
			changed = true
	if changed:
		_recompute()
	if get_tree().paused:
		return
	if event.is_action_pressed(&"jump", false):
		jump_pressed.emit()
	if event.is_action_pressed(&"attack", false):
		attack_pressed.emit()

## Drops every held direction (focus lost, scene change).
func release_all() -> void:
	for action in MOVE_ACTIONS:
		(_strengths[action] as Dictionary).clear()
	_move = Vector2.ZERO

func _strength(action: StringName) -> float:
	var best: float = 0.0
	for value: float in (_strengths[action] as Dictionary).values():
		best = maxf(best, value)
	return best

func _recompute() -> void:
	_move = Vector2(
		_strength(MOVE_RIGHT) - _strength(MOVE_LEFT),
		_strength(MOVE_BACK) - _strength(MOVE_FORWARD)).limit_length(1.0)

func _source_of(event: InputEvent) -> String:
	return "%s:%d" % [event.get_class(), event.device]
