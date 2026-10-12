extends CanvasLayer

const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"
const TITLE_TEXT: String = "Привал"
const RESUME_TEXT: String = "Продолжить путь"
const RESTART_TEXT: String = "Начать заново"
const MENU_TEXT: String = "Покинуть подземелье"

@onready var _resume_button: Button = %ResumeButton
@onready var _restart_button: Button = %RestartButton
@onready var _menu_button: Button = %MenuButton
@onready var _title: Label = $Panel/Content/Title

func _ready() -> void:
	# keeps receiving input while everything else is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_title.text = TITLE_TEXT
	_resume_button.text = RESUME_TEXT
	_restart_button.text = RESTART_TEXT
	_menu_button.text = MENU_TEXT
	_resume_button.pressed.connect(set_paused.bind(false))
	_restart_button.pressed.connect(_on_restart_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause", false):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()

func set_paused(value: bool) -> void:
	get_tree().paused = value
	visible = value
	if value:
		_resume_button.grab_focus()

func _on_restart_pressed() -> void:
	# a reloaded scene would start frozen otherwise
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
