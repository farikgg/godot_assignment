class_name SlashArc
extends MeshInstance3D
## Sword trail: a half ring in front of the hero (opening along -Z, the swing direction),
## sweeps open and fades over `duration`, then frees itself. Built as a mesh here, coloured by
## shaders/slash_arc.gdshader through the per-instance `progress` parameter.

@export var duration: float = 0.15
@export var inner_radius: float = 0.35
@export var outer_radius: float = 1.15
@export var arc_degrees: float = 170.0
@export var segments: int = 24
## The ring starts a little smaller and opens to full size.
@export var start_scale: float = 0.75

func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _build_mesh()
	set_instance_shader_parameter(&"progress", 0.0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_method(_set_progress, 0.0, 1.0, duration)
	# explicit from: the owner sets the transform after add_child, which would reset a scale set here
	tween.tween_property(self, "scale", Vector3.ONE, duration * 0.6).from(Vector3.ONE * start_scale) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(queue_free)

func _set_progress(value: float) -> void:
	set_instance_shader_parameter(&"progress", value)

# flat ring sector in the XZ plane, centred on -Z; UV.x along the arc, UV.y across it
func _build_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = deg_to_rad(arc_degrees) * 0.5
	for i in segments:
		var t0: float = float(i) / float(segments)
		var t1: float = float(i + 1) / float(segments)
		var a0: float = lerpf(half, -half, t0)
		var a1: float = lerpf(half, -half, t1)
		var dir0 := Vector3(sin(a0), 0.0, -cos(a0))
		var dir1 := Vector3(sin(a1), 0.0, -cos(a1))
		var quad: Array[Array] = [
			[dir0 * inner_radius, Vector2(t0, 0.0)], [dir0 * outer_radius, Vector2(t0, 1.0)],
			[dir1 * outer_radius, Vector2(t1, 1.0)], [dir1 * inner_radius, Vector2(t1, 0.0)],
		]
		for index in [0, 1, 2, 0, 2, 3]:
			tool.set_uv(quad[index][1])
			tool.add_vertex(quad[index][0])
	return tool.commit()
