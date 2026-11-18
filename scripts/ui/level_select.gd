extends PanelContainer
## "Choose a level" panel: one button per LevelData in the catalog, locked ones disabled,
## with the best coins and time from SaveGame. Opened by "Спуститься" in the main menu.

signal closed

const TITLE_TEXT: String = "Выбери уровень"
const BACK_TEXT: String = "Назад"
const LOCKED_TEXT: String = "Закрыт — пройди предыдущий уровень"
const NOT_PLAYED_TEXT: String = "Ещё не пройден"
const BEST_TEXT: String = "Рекорд: %d зол. · %s"
const PAR_TEXT: String = " (цель %s)"
const NO_TIME_TEXT: String = "—"
const TIME_FORMAT: String = "%d:%02d"
const SECONDS_PER_MINUTE: int = 60
const LEVEL_BUTTON_SIZE: Vector2 = Vector2(760, 150)
## Smaller than the 40 px of a button title, still above the 36 px readability floor.
const STATS_FONT_SIZE: int = 36

@onready var _title: Label = %TitleLabel
@onready var _list: VBoxContainer = %LevelList
@onready var _back_button: Button = %BackButton

func _ready() -> void:
	_title.text = TITLE_TEXT
	_back_button.text = BACK_TEXT
	_back_button.pressed.connect(close)
	visible = false

func open() -> void:
	_rebuild()
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

# rebuilt on every open so a reset or a new record shows at once
func _rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var focus: Button = null
	var levels: Array[LevelData] = GameFlow.levels()
	for i in levels.size():
		var level: LevelData = levels[i]
		if level == null:
			continue
		var button: Button = _make_button(level)
		button.pressed.connect(_on_level_pressed.bind(i))
		_list.add_child(button)
		# continue where the player stopped: focus the last open level in catalog order
		if not button.disabled:
			focus = button
	if focus != null:
		focus.grab_focus()
	else:
		_back_button.grab_focus()

func _make_button(level: LevelData) -> Button:
	var unlocked: bool = SaveGame.is_level_unlocked(level.id)
	var button := Button.new()
	button.custom_minimum_size = LEVEL_BUTTON_SIZE
	button.disabled = not unlocked
	button.tooltip_text = level.title
	# two lines (title, record) as labels: a Button's own text is a single line
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lines.add_child(_make_line(level.title, button.get_theme_font_size(&"font_size")))
	lines.add_child(_make_line(_stats_text(level, unlocked), STATS_FONT_SIZE))
	if not unlocked:
		lines.modulate.a = button.get_theme_color(&"font_disabled_color").a
	button.add_child(lines)
	return button

func _make_line(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _stats_text(level: LevelData, unlocked: bool) -> String:
	if not unlocked:
		return LOCKED_TEXT
	var par: String = PAR_TEXT % _format_time(level.par_time_sec) if level.par_time_sec > 0.0 else ""
	if not SaveGame.best_score.has(level.id):
		return NOT_PLAYED_TEXT + par
	var time: float = SaveGame.best_time_sec.get(level.id, 0.0)
	var time_text: String = _format_time(time) if time > 0.0 else NO_TIME_TEXT
	return BEST_TEXT % [SaveGame.best_score[level.id], time_text] + par

func _format_time(seconds: float) -> String:
	var total: int = ceili(seconds)
	return TIME_FORMAT % [total / SECONDS_PER_MINUTE, total % SECONDS_PER_MINUTE]

func _on_level_pressed(index: int) -> void:
	GameFlow.start_level(index)
