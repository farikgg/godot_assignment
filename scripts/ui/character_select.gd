extends PanelContainer
## "Choose your hero" panel: arrows, name, a turning 3D preview and a select button.

signal closed

const TITLE_TEXT: String = "Выбери героя"
const SELECT_TEXT: String = "Выбрать"
const SELECTED_TEXT: String = "Выбран"
const BACK_TEXT: String = "Назад"

## Turntable speed in the preview, degrees per second.
@export var spin_speed: float = 30.0

@onready var _title: Label = %TitleLabel
@onready var _name_label: Label = %HeroNameLabel
@onready var _prev_button: Button = %PrevButton
@onready var _next_button: Button = %NextButton
@onready var _select_button: Button = %SelectButton
@onready var _back_button: Button = %BackButton
@onready var _turntable: Node3D = %Turntable

var _index: int = 0
var _preview: Node3D

func _ready() -> void:
	_title.text = TITLE_TEXT
	_back_button.text = BACK_TEXT
	_prev_button.pressed.connect(_step.bind(-1))
	_next_button.pressed.connect(_step.bind(1))
	_select_button.pressed.connect(_on_select_pressed)
	_back_button.pressed.connect(close)
	visible = false

func _process(delta: float) -> void:
	if visible:
		_turntable.rotate_y(deg_to_rad(spin_speed) * delta)

func open() -> void:
	_index = maxi(Roster.roster.index_of(Profile.character_id), 0)
	_show_current()
	visible = true
	_select_button.grab_focus()

func close() -> void:
	visible = false
	closed.emit()

func current() -> CharacterData:
	var all: Array[CharacterData] = Roster.all()
	return all[_index] if _index < all.size() else null

func _step(direction: int) -> void:
	var count: int = Roster.all().size()
	if count == 0:
		return
	_index = posmod(_index + direction, count)
	_show_current()

func _show_current() -> void:
	var data: CharacterData = current()
	if data == null:
		push_error("CharacterSelect: roster is empty")
		return
	_name_label.text = data.display_name
	_refresh_select_button()
	if _preview != null:
		_preview.queue_free()
		_preview = null
	if data.model == null:
		push_error("CharacterSelect: %s has no model" % data.id)
		return
	_preview = data.model.instantiate() as Node3D
	_turntable.add_child(_preview)
	for node in _preview.find_children("*", "AnimationPlayer", true, false):
		var anim: AnimationPlayer = node as AnimationPlayer
		if data.anim_idle != &"" and anim.has_animation(data.anim_idle):
			anim.get_animation(data.anim_idle).loop_mode = Animation.LOOP_LINEAR
			anim.play(data.anim_idle)
		break

func _refresh_select_button() -> void:
	var data: CharacterData = current()
	var chosen: bool = data != null and data.id == Profile.character_id
	_select_button.text = SELECTED_TEXT if chosen else SELECT_TEXT
	_select_button.disabled = chosen

func _on_select_pressed() -> void:
	var data: CharacterData = current()
	if data == null:
		return
	Profile.set_character(data.id)
	_refresh_select_button()
