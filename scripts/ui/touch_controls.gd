extends CanvasLayer
## On-screen stick and buttons above the HUD. Positions are set here from edge_margin,
## so the controls can be moved towards the centre in the inspector without touching every node.

## Show on desktop too (needed for the A7 video); on touch devices they are always shown.
@export var show_on_desktop: bool = true
## Distance of the stick and the action buttons from the side edges (x) and the bottom (y),
## in base-resolution pixels (1920 × 1080). Larger = closer to the thumbs.
@export var edge_margin: Vector2 = Vector2(140.0, 90.0):
	set(value):
		edge_margin = value
		if is_node_ready():
			_layout()
## Distance of the pause button from the top edge.
@export var top_margin: float = 40.0
## Gap between neighbouring buttons.
@export var button_gap: float = 30.0

@onready var _stick: Control = $Root/Stick
@onready var _attack: Control = $Root/AttackButton
@onready var _jump: Control = $Root/JumpButton
@onready var _pause: Control = $Root/PauseButton
@onready var _camera_left: Control = $Root/CameraLeftButton
@onready var _camera_right: Control = $Root/CameraRightButton

func _ready() -> void:
	# a finger lifted during the pause must still release the stick / button
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = show_on_desktop or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	_layout()

func _layout() -> void:
	var m: Vector2 = edge_margin
	# stick: bottom-left corner
	_place(_stick, Vector2(0.0, 1.0), Vector2(m.x, -m.y - _stick.size.y))
	# attack: bottom-right corner; jump to its left, a little lower (the thumb's arc)
	var attack_x: float = -m.x - _attack.size.x
	_place(_attack, Vector2(1.0, 1.0), Vector2(attack_x, -m.y - _attack.size.y))
	var jump_x: float = attack_x - button_gap - _jump.size.x
	_place(_jump, Vector2(1.0, 1.0), Vector2(jump_x, -m.y + 10.0 - _jump.size.y))
	# pause: top-right, in line with the attack button
	_place(_pause, Vector2(1.0, 0.0), Vector2(-m.x - _pause.size.x, top_margin))
	# camera arrows: right edge, just above the vertical middle
	var right_x: float = -m.x - _camera_right.size.x
	_place(_camera_right, Vector2(1.0, 0.5), Vector2(right_x, -_camera_right.size.y))
	_place(_camera_left, Vector2(1.0, 0.5),
		Vector2(right_x - button_gap - _camera_left.size.x, -_camera_left.size.y))

# anchors all four sides to `anchor` and puts the control's top-left at `offset` from it, keeping its size
func _place(control: Control, anchor: Vector2, offset: Vector2) -> void:
	var size: Vector2 = control.size
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = offset.x
	control.offset_top = offset.y
	control.offset_right = offset.x + size.x
	control.offset_bottom = offset.y + size.y
