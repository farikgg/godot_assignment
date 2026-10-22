class_name PlayerInputHandler
extends Node


signal jump_pressed
signal attack_pressed

const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const MOVE_FORWARD: StringName = &"move_forward"
const MOVE_BACK: StringName = &"move_back"
const MOVE_ACTIONS: Array[StringName] = [MOVE_LEFT, MOVE_RIGHT, MOVE_FORWARD, MOVE_BACK]

## Для внешних только read. Доступ через .move
var move: Vector2:
	get:
		return _move
	set(_value):
		push_error("PlayerInputHandler.move is read-only")

var _move: Vector2 = Vector2.ZERO
# Для сборка всех input при передвижении, чтобы одно не перезатирало другое
var _strengths: Dictionary = {}

func _ready() -> void:
	# получает input даже при паузе
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in MOVE_ACTIONS:
		_strengths[action] = {}

func _notification(what: int) -> void:
	# при alt + tab
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_all()

func _unhandled_input(event: InputEvent) -> void:
	var changed: bool = false
	for action in MOVE_ACTIONS:
		if event.is_action(action):
			# стик сила от 0 до 1, кнопка сила 0 или 1
			(_strengths[action] as Dictionary)[_source_of(event)] = event.get_action_strength(action)
			changed = true
	if changed:
		_recompute()
	if get_tree().paused:
		return
	# echo = false
	if event.is_action_pressed(&"jump", false):
		jump_pressed.emit()
	if event.is_action_pressed(&"attack", false):
		attack_pressed.emit()

## сброс всех нажатий
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
