class_name Toast
extends Control
## Compact top-centre notification in the HUD frame style; fades in, waits, fades out.

const TOP_MARGIN: float = 24.0
const SLIDE_DISTANCE: float = 16.0
const FADE_IN_TIME: float = 0.2
const FADE_OUT_TIME: float = 0.3
## The panel never gets wider than this share of the visible screen; longer text wraps.
const MAX_WIDTH_SHARE: float = 0.4

## Distance from the top of the screen; the HUD moves it down while the boss bar is shown.
var top_margin: float = TOP_MARGIN

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/Text

var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	_panel.visible = false
	# a Label reshapes its wrapped lines a frame later; refit the plate whenever that settles
	_panel.minimum_size_changed.connect(_fit_panel)

## Shows `text` for `duration` seconds; duration <= 0 keeps it until the next toast or hide_toast().
## A toast raised while the game is paused animates during the pause; any other one freezes with the game.
func show_toast(text: String, duration: float = 2.5) -> void:
	var replacing: bool = is_showing()
	_kill_tween()
	_label.text = text
	_layout()
	_panel.visible = true
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS if get_tree().paused else Tween.TWEEN_PAUSE_BOUND)
	if replacing:
		# swap the text in place and restart the wait; no second fade-in, no overlap
		_panel.modulate.a = 1.0
		_panel.position.y = top_margin
	else:
		_panel.modulate.a = 0.0
		_panel.position.y = top_margin - SLIDE_DISTANCE
		_tween.set_parallel(true)
		_tween.tween_property(_panel, "modulate:a", 1.0, FADE_IN_TIME)
		_tween.tween_property(_panel, "position:y", top_margin, FADE_IN_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.set_parallel(false)
	if duration > 0.0:
		_tween.tween_interval(duration)
		_tween.tween_property(_panel, "modulate:a", 0.0, FADE_OUT_TIME)
		_tween.tween_callback(_hide_now)
	elif replacing:
		# a persistent text swapped in place: nothing to animate
		_kill_tween()

func hide_toast() -> void:
	if not is_showing():
		return
	_kill_tween()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS if get_tree().paused else Tween.TWEEN_PAUSE_BOUND)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_OUT_TIME)
	_tween.tween_callback(_hide_now)

func is_showing() -> bool:
	return _panel.visible and _panel.modulate.a > 0.0

func current_text() -> String:
	return _label.text if is_showing() else ""

## On-screen rectangle of the plate, for layout checks.
func panel_rect() -> Rect2:
	return _panel.get_global_rect()

# width follows the text up to MAX_WIDTH_SHARE of the screen, then the label wraps
func _layout() -> void:
	var screen_width: float = get_viewport_rect().size.x
	var style: StyleBox = _panel.get_theme_stylebox(&"panel")
	var frame: float = style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT) if style != null else 0.0
	var font: Font = _label.get_theme_font(&"font")
	var font_size: int = _label.get_theme_font_size(&"font_size")
	var text_width: float = font.get_multiline_string_size(_label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	text_width += _label.get_theme_constant(&"outline_size") * 2.0
	var max_text_width: float = maxf(screen_width * MAX_WIDTH_SHARE - frame, 80.0)
	_label.custom_minimum_size = Vector2(minf(ceilf(text_width), max_text_width), 0.0)
	_fit_panel()

# PanelContainer outside a container never shrinks by itself: size it to its minimum and recentre
func _fit_panel() -> void:
	_panel.size = Vector2.ZERO
	_panel.reset_size()
	_panel.position.x = (get_viewport_rect().size.x - _panel.size.x) * 0.5

func _hide_now() -> void:
	_panel.visible = false
	_panel.modulate.a = 0.0
	_label.text = ""

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
