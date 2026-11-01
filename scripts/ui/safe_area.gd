class_name SafeArea
extends MarginContainer
## Full-screen container that keeps its content out of the display's cut-outs (notch, rounded
## corners, home indicator). Its margins are the safe-area insets converted from the window's
## physical pixels into UI coordinates (stretch mode canvas_items / expand).
##
## Put ONE full-size Control inside it and anchor the real widgets to that child: a MarginContainer
## stretches its direct children over the whole safe rect. Backgrounds and dimmers stay outside.
## On desktop the safe area is the whole window; DevicePreview (debug builds) can stand in a phone's.

## Applied margins in UI units: x = left, y = top, z = right, w = bottom.
var insets: Vector4 = Vector4.ZERO

func _init() -> void:
	# never eat clicks or touches meant for the game or for controls underneath
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(update_insets)
	var preview: Node = get_node_or_null("/root/DevicePreview")
	if preview != null and preview.has_signal("preset_changed"):
		preview.connect("preset_changed", update_insets)
	update_insets()

## Re-reads the safe area and window size and applies the margins.
func update_insets() -> void:
	var window_size := Vector2(get_window().size)
	insets = compute_insets(_safe_rect_in_window(window_size), window_size, get_viewport().get_visible_rect().size)
	add_theme_constant_override(&"margin_left", roundi(insets.x))
	add_theme_constant_override(&"margin_top", roundi(insets.y))
	add_theme_constant_override(&"margin_right", roundi(insets.z))
	add_theme_constant_override(&"margin_bottom", roundi(insets.w))

## Insets (left, top, right, bottom) in UI units for a safe rect given in the window's physical
## pixels. `visible_size` is the viewport's visible rect in UI units, so visible / window is the
## UI-units-per-pixel factor of the stretch mode (equal on both axes with aspect "expand").
static func compute_insets(safe_rect: Rect2, window_size: Vector2, visible_size: Vector2) -> Vector4:
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return Vector4.ZERO
	var scale: Vector2 = visible_size / window_size
	var left: float = maxf(safe_rect.position.x, 0.0) * scale.x
	var top: float = maxf(safe_rect.position.y, 0.0) * scale.y
	var right: float = maxf(window_size.x - safe_rect.end.x, 0.0) * scale.x
	var bottom: float = maxf(window_size.y - safe_rect.end.y, 0.0) * scale.y
	return Vector4(left, top, right, bottom)

# safe rect relative to the window's top-left corner, in physical pixels
func _safe_rect_in_window(window_size: Vector2) -> Rect2:
	var preview: Node = get_node_or_null("/root/DevicePreview")
	if preview != null and preview.has_method("is_active") and preview.call("is_active"):
		return preview.call("safe_rect_in_window")
	if OS.has_feature("mobile"):
		var safe := Rect2(DisplayServer.get_display_safe_area())
		safe.position -= Vector2(DisplayServer.window_get_position())
		return safe.intersection(Rect2(Vector2.ZERO, window_size))
	return Rect2(Vector2.ZERO, window_size)
