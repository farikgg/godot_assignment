extends Control

const START_TEXT: String = "Спуститься"
const HEROES_TEXT: String = "Герои"
const SETTINGS_TEXT: String = "Настройки"
const QUIT_TEXT: String = "Выйти"
const NAME_PLACEHOLDER: String = "Имя героя"
const MUSIC_TEXT: String = "Громкость музыки"
const SFX_TEXT: String = "Громкость звуков"
const RESET_TEXT: String = "Сбросить прогресс"
const RESET_QUESTION: String = "Сбросить прогресс? Открытые уровни, рекорды и золото пропадут. Имя и громкость останутся."

@onready var settings_panel: Control = $SafeArea/Content/SettingsPanel
@onready var main_menu: Control = $SafeArea/Content/MainPanel
@onready var volume_slider: HSlider = $"SafeArea/Content/SettingsPanel/Content/Music volume"
@onready var sfx_slider: HSlider = $SafeArea/Content/SettingsPanel/Content/SfxVolume
@onready var reset_button: Button = $SafeArea/Content/SettingsPanel/Content/ButtonReset
@onready var name_field: LineEdit = $SafeArea/Content/MainPanel/Buttons/NameField
@onready var sign_board: Control = $SafeArea/Content/Sign
@onready var character_select: Control = $SafeArea/Content/CharacterSelect
@onready var level_select: Control = $SafeArea/Content/LevelSelect
@onready var confirm_panel: ConfirmPanel = $ConfirmPanel

func _ready() -> void:
	($SafeArea/Content/MainPanel/Buttons/Grid/ButtonStart as Button).text = START_TEXT
	($SafeArea/Content/MainPanel/Buttons/Grid/ButtonHeroes as Button).text = HEROES_TEXT
	($SafeArea/Content/MainPanel/Buttons/Grid/ButtonSetting as Button).text = SETTINGS_TEXT
	($SafeArea/Content/MainPanel/Buttons/Grid/ButtonQuit as Button).text = QUIT_TEXT
	($SafeArea/Content/SettingsPanel/Content/Label as Label).text = MUSIC_TEXT
	($SafeArea/Content/SettingsPanel/Content/SfxLabel as Label).text = SFX_TEXT
	reset_button.text = RESET_TEXT
	name_field.placeholder_text = NAME_PLACEHOLDER
	name_field.max_length = SaveGame.MAX_NAME_LENGTH
	name_field.text = Profile.player_name
	character_select.connect("closed", _on_subpanel_closed)
	level_select.connect("closed", _on_subpanel_closed)
	confirm_panel.confirmed.connect(_on_reset_confirmed)
	confirm_panel.cancelled.connect(reset_button.grab_focus)
	MusicPlayer.play_menu()
	_show_settings_values()

func _show_settings_values() -> void:
	volume_slider.set_value_no_signal(SaveGame.music_volume)
	sfx_slider.set_value_no_signal(SaveGame.sfx_volume)

# the level select doubles as "continue": it opens on the last unlocked level
func _on_button_start_pressed() -> void:
	main_menu.visible = false
	sign_board.visible = false
	level_select.call("open")

func _on_button_quit_pressed() -> void:
	GameFlow.quit_game()

func _on_button_heroes_pressed() -> void:
	main_menu.visible = false
	sign_board.visible = false
	character_select.call("open")

# shared by the hero and level panels
func _on_subpanel_closed() -> void:
	sign_board.visible = true
	main_menu.visible = true

func _on_button_settings_pressed() -> void:
	main_menu.visible = false
	settings_panel.visible = true

func _on_button_back_pressed() -> void:
	settings_panel.visible = false
	main_menu.visible = true

func _on_volume_slider_value_changed(value: float) -> void:
	SaveGame.set_music_volume(value)

func _on_sfx_slider_value_changed(value: float) -> void:
	SaveGame.set_sfx_volume(value)

func _on_button_reset_pressed() -> void:
	confirm_panel.ask(RESET_QUESTION)

func _on_reset_confirmed() -> void:
	SaveGame.reset()
	_show_settings_values()
	reset_button.grab_focus()

func _on_name_field_text_changed(new_text: String) -> void:
	Profile.set_player_name(new_text)
