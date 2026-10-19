extends Control
## Shown after the last level: title, gold gathered over the run, back to the main menu.

const TITLE_TEXT: String = "Ты выбрался на свет!"
const GOLD_TEXT: String = "Золота собрано: %d"
const MENU_TEXT: String = "В главное меню"

@onready var _title: Label = %TitleLabel
@onready var _gold: Label = %GoldLabel
@onready var _menu_button: Button = %MenuButton

func _ready() -> void:
	_title.text = TITLE_TEXT
	_gold.text = GOLD_TEXT % GameFlow.total_coins
	_menu_button.text = MENU_TEXT
	_menu_button.pressed.connect(_on_menu_pressed)
	_menu_button.grab_focus()

func _on_menu_pressed() -> void:
	GameFlow.go_to_menu()
