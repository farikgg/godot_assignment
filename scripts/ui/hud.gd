class_name Hud
extends CanvasLayer
## Heads-up display. main.gd talks to it only through these methods.

const NAME_CAPTION_TEXT: String = "Игрок:"
const GOLD_TEXT: String = "Золото: %d / %d"
const CAVE_IN_TEXT: String = "Обвал стихнет через %d"
const HAS_KEY_TEXT: String = "Ключ: есть"
const NO_KEY_TEXT: String = "Ключ: нет"
const HEART_FULL: Texture2D = preload("res://assets/ui_gen/heart_full.png")
const HEART_EMPTY: Texture2D = preload("res://assets/ui_gen/heart_empty.png")

@onready var _name_caption: Label = %NameCaption
@onready var _name_label: Label = %NameLabel
@onready var _hearts_box: HBoxContainer = %HeartsBox
@onready var _coin_label: Label = %CoinLabel
@onready var _key_label: Label = %KeyLabel
@onready var _survival_label: Label = %SurvivalLabel
@onready var _toast: Toast = %Toast

func _ready() -> void:
	_name_caption.text = NAME_CAPTION_TEXT

func set_player_name(player_name: String) -> void:
	_name_label.text = player_name

func set_hearts(current: int, max_hp: int) -> void:
	var hearts: Array[Node] = _hearts_box.get_children()
	if hearts.size() != max_hp:
		push_error("Hud: HeartsBox has %d icons for max_hp %d" % [hearts.size(), max_hp])
	for i in hearts.size():
		var icon: TextureRect = hearts[i] as TextureRect
		if icon != null:
			icon.texture = HEART_FULL if i < current else HEART_EMPTY

func set_coins(collected: int, total: int) -> void:
	_coin_label.text = GOLD_TEXT % [collected, total]

func set_key(has_key: bool) -> void:
	_key_label.text = HAS_KEY_TEXT if has_key else NO_KEY_TEXT

func set_survival_time(seconds_left: int) -> void:
	_survival_label.text = CAVE_IN_TEXT % seconds_left

## Shown as a toast at the top centre. duration <= 0 keeps it until the next message (win, game over).
func show_message(text: String, duration: float = 0.0) -> void:
	_toast.show_toast(text, duration)

func clear_message() -> void:
	_toast.hide_toast()
