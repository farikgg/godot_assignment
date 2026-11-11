class_name VisionDebug
extends MeshInstance3D
## Debug drawing of an Enemy's sight: the view cone at eye height and the ray to the hero
## (green = sees the hero, red = a wall is in the way). Enemy adds it in debug builds only.

## Line segments in the arc of the cone.
const ARC_STEPS: int = 12
const CONE_COLOR: Color = Color(1.0, 0.9, 0.2)
const SEES_COLOR: Color = Color(0.2, 1.0, 0.3)
const BLOCKED_COLOR: Color = Color(1.0, 0.2, 0.2)

## Width of every drawn line.
@export var line_thickness: float = 0.06  # m

var _enemy: Enemy
var _lines := ImmediateMesh.new()

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		push_warning("VisionDebug: parent is not an Enemy, nothing to draw")
		set_process(false)
		return
	# vertices are given in world space, so the node must not inherit the enemy's transform
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _lines
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	# the lines are flat ribbons that must be visible from both sides
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material

func _process(_delta: float) -> void:
	_lines.clear_surfaces()
	if _enemy.is_dead():
		return
	_lines.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_draw_cone()
	_draw_ray()
	_lines.surface_end()

func _draw_cone() -> void:
	var eye: Vector3 = _enemy.eye_position()
	var half_angle: float = deg_to_rad(_enemy.fov_degrees * 0.5)
	var previous: Vector3 = eye
	for step in ARC_STEPS + 1:
		var angle: float = lerpf(-half_angle, half_angle, float(step) / float(ARC_STEPS))
		var point: Vector3 = eye + _enemy.get_facing().rotated(Vector3.UP, angle) * _enemy.view_range
		_line(previous, point, CONE_COLOR)
		previous = point
	_line(previous, eye, CONE_COLOR)

# asks the enemy for a fresh sight check, so the picture is right in every state
func _draw_ray() -> void:
	match _enemy.look_for_player():
		Enemy.Sight.CLEAR:
			var target: Vector3 = _enemy.get_hero().global_position + Vector3.UP * _enemy.target_height
			_line(_enemy.eye_position(), target, SEES_COLOR)
		Enemy.Sight.BLOCKED:
			_line(_enemy.eye_position(), _enemy.sight_block_point, BLOCKED_COLOR)

# a line as a flat ribbon lying in the ground plane: two triangles, line_thickness wide
func _line(from: Vector3, to: Vector3, color: Color) -> void:
	var side: Vector3 = (to - from).cross(Vector3.UP).normalized() * line_thickness * 0.5
	for corner in [from - side, from + side, to + side, from - side, to + side, to - side]:
		_lines.surface_set_color(color)
		_lines.surface_add_vertex(corner)
