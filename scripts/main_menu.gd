extends Control

@onready var settings_panel: Control = $SettingsPanel
@onready var main_menu: Control = $MainPanel
@onready var music: AudioStreamPlayer = $Music
@onready var volume_slider: HSlider = $"SettingsPanel/Content/Music volume"

func _on_button_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/map.tscn")

func _on_button_quit_pressed() -> void:
	get_tree().quit()

func _on_button_settings_pressed() -> void:
	main_menu.visible = false
	settings_panel.visible = true

func _on_button_back_pressed() -> void:
	settings_panel.visible = false
	main_menu.visible = true

func _on_volume_slider_value_changed(value: float) -> void:
	if value <= 0.0:
		music.volume_db = -80.0
	else:
		music.volume_db = linear_to_db(value)

func _on_name_field_text_changed(new_text: String) -> void:
	Profile.set_player_name(new_text)
