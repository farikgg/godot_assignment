class_name TelegraphMarker
extends Node3D
## Warning circle on the floor: grows to full size over grow(time), then emits `finished`.
## Used by the cave-in spawner (dark shadow) and the boss's fire rain (red circle with «!»).
## The owner frees it, so the circle can stay until the thing it warns about lands.

signal finished

@export var radius: float = 0.7
@export var color: Color = Color(0.05, 0.05, 0.09, 0.55)
## Shows the «!» sign above the circle.
@export var show_mark: bool = false
## Circle size at the start of grow(), as a share of radius.
@export var start_scale: float = 0.15

@onready var _circle: MeshInstance3D = $Circle
@onready var _mark: Label3D = $Mark

func _ready() -> void:
	_circle.mesh = _make_mesh()
	_circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.visible = show_mark

## Grows the circle over `time` seconds; the tween pauses with the game.
func grow(time: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_circle, "scale", Vector3.ONE, maxf(time, 0.01)) \
		.from(Vector3(start_scale, 1.0, start_scale))
	tween.finished.connect(finished.emit)

func _make_mesh() -> CylinderMesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	mesh.radial_segments = 32
	mesh.material = material
	return mesh
