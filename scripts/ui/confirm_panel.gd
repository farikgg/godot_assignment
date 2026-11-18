class_name ConfirmPanel
extends Control
## In-game yes / cancel question over the current screen (no OS dialog: works the same on phones).
## ask() shows it; exactly one of confirmed / cancelled follows.

signal confirmed
signal cancelled

const YES_TEXT: String = "Да"
const CANCEL_TEXT: String = "Отмена"

@onready var _message: Label = %Message
@onready var _yes_button: Button = %YesButton
@onready var _cancel_button: Button = %CancelButton

func _ready() -> void:
	# keeps working when opened over a paused game
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_yes_button.text = YES_TEXT
	_cancel_button.text = CANCEL_TEXT
	_yes_button.pressed.connect(_answer.bind(true))
	_cancel_button.pressed.connect(_answer.bind(false))

func ask(message: String) -> void:
	_message.text = message
	visible = true
	# the safe default under the cursor / controller focus
	_cancel_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_answer(false)

func _answer(yes: bool) -> void:
	if not visible:
		return
	visible = false
	if yes:
		confirmed.emit()
	else:
		cancelled.emit()
