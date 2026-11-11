class_name ModelFlash
extends Node
## Telegraph flash: a translucent colour laid over every mesh of a model, growing stronger
## over the wind-up. The overlay is attached only while a flash plays.

var _meshes: Array[MeshInstance3D] = []
var _material := StandardMaterial3D.new()
var _tween: Tween

## Collects the meshes under `root` (call once, after the model is in the tree).
func setup(root: Node3D) -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for node in root.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)
	if _meshes.is_empty():
		push_warning("ModelFlash: no meshes under %s, the flash will not show" % root.name)

## Fades the overlay from clear to `color` at `peak_alpha` over `time` seconds.
func play(color: Color, peak_alpha: float, time: float) -> void:
	stop()
	_set_overlay(_material)
	# the tween belongs to this node, so it pauses with the game and dies with the enemy
	_tween = create_tween()
	_tween.tween_property(_material, "albedo_color", Color(color, peak_alpha), maxf(time, 0.0)) \
		.from(Color(color, 0.0))

func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_set_overlay(null)

func _set_overlay(material: Material) -> void:
	for mesh in _meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = material
