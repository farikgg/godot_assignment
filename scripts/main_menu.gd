extends Control

const START_TEXT: String = "Спуститься"
const HEROES_TEXT: String = "Герои"
const SETTINGS_TEXT: String = "Настройки"
const QUIT_TEXT: String = "Выйти"
const NAME_PLACEHOLDER: String = "Имя героя"

@onready var settings_panel: Control = $SettingsPanel
@onready var main_menu: Control = $MainPanel
@onready var volume_slider: HSlider = $"SettingsPanel/Content/Music volume"
@onready var sign_board: Control = $Sign
@onready var character_select: Control = $CharacterSelect

func _ready() -> void:
	($MainPanel/Buttons/ButtonStart as Button).text = START_TEXT
	($MainPanel/Buttons/ButtonHeroes as Button).text = HEROES_TEXT
	($MainPanel/Buttons/ButtonSetting as Button).text = SETTINGS_TEXT
	($MainPanel/Buttons/ButtonQuit as Button).text = QUIT_TEXT
	($MainPanel/Buttons/NameField as LineEdit).placeholder_text = NAME_PLACEHOLDER
	character_select.connect("closed", _on_character_select_closed)
	MusicPlayer.play_menu()
	volume_slider.set_value_no_signal(MusicPlayer.get_volume_linear())

func _on_button_start_pressed() -> void:
	GameFlow.start_game()

func _on_button_quit_pressed() -> void:
	GameFlow.quit_game()

func _on_button_heroes_pressed() -> void:
	main_menu.visible = false
	sign_board.visible = false
	character_select.call("open")

func _on_character_select_closed() -> void:
	sign_board.visible = true
	main_menu.visible = true

func _on_button_settings_pressed() -> void:
	main_menu.visible = false
	settings_panel.visible = true

func _on_button_back_pressed() -> void:
	settings_panel.visible = false
	main_menu.visible = true

func _on_volume_slider_value_changed(value: float) -> void:
	MusicPlayer.set_volume_linear(value)

func _on_name_field_text_changed(new_text: String) -> void:
	Profile.set_player_name(new_text)
