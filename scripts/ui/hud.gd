class_name Hud
extends CanvasLayer
## Heads-up display. level.gd talks to it only through these methods.

const NAME_CAPTION_TEXT: String = "Игрок:"
const GOLD_TEXT: String = "Золото: %d / %d"
const HAS_KEY_TEXT: String = "Ключ: есть"
const NO_KEY_TEXT: String = "Ключ: нет"
const HEART_FULL: Texture2D = preload("res://assets/ui_gen/heart_full.png")
const HEART_EMPTY: Texture2D = preload("res://assets/ui_gen/heart_empty.png")
## Seconds the boss bar takes to slide down to the new HP.
const BOSS_BAR_DRAIN_TIME: float = 0.4
## Gap between the boss bar and a toast below it.
const BOSS_BAR_GAP: float = 12.0

@onready var _name_caption: Label = %NameCaption
@onready var _name_label: Label = %NameLabel
@onready var _hearts_box: HBoxContainer = %HeartsBox
@onready var _coin_label: Label = %CoinLabel
@onready var _key_label: Label = %KeyLabel
@onready var _toast: Toast = %Toast
@onready var _boss_bar: PanelContainer = %BossBar
@onready var _boss_name: Label = %BossName
@onready var _boss_hp: ProgressBar = %BossHp

var _boss_tween: Tween

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

## Shown as a toast at the top centre. duration <= 0 keeps it until the next message (win, game over).
func show_message(text: String, duration: float = 0.0) -> void:
	_toast.show_toast(text, duration)

func clear_message() -> void:
	_toast.hide_toast()

## Boss health bar at the top centre; toasts move below it while it is shown.
func show_boss_bar(title: String, current: int, max_hp: int) -> void:
	_boss_name.text = title
	_boss_hp.max_value = max_hp
	_boss_hp.value = current
	_boss_bar.visible = true
	_toast.top_margin = _boss_bar.position.y + _boss_bar.get_combined_minimum_size().y + BOSS_BAR_GAP

## Drains the bar smoothly to `current`.
func set_boss_hp(current: int, max_hp: int) -> void:
	_boss_hp.max_value = max_hp
	if _boss_tween != null and _boss_tween.is_valid():
		_boss_tween.kill()
	_boss_tween = create_tween()
	_boss_tween.tween_property(_boss_hp, "value", float(current), BOSS_BAR_DRAIN_TIME) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func hide_boss_bar() -> void:
	_boss_bar.visible = false
	_toast.top_margin = Toast.TOP_MARGIN

func is_boss_bar_visible() -> bool:
	return _boss_bar.visible

## Value the bar shows right now (mid-drain included), for tests.
func boss_bar_value() -> float:
	return _boss_hp.value
