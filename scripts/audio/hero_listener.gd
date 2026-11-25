class_name HeroListener
extends AudioListener3D
## The ears of the game: placed on the hero, turned like the camera. The camera is orthographic
## and ~30 m away, so as the default listener every sound would be about equally far; here the
## distance is hero -> source, and left/right is screen left/right (not the hero's facing, which
## spins as it runs).

var _height: float = 0.0

func _ready() -> void:
	# own transform: the parent's rotation must not turn the ears
	top_level = true
	_height = AudioMix.get_mix().listener_height
	if get_parent() is not Node3D:
		push_error("HeroListener: parent %s is not a Node3D, the listener stays still" % get_parent())
	make_current()
	_follow()

func _process(_delta: float) -> void:
	_follow()

func _follow() -> void:
	var hero: Node3D = get_parent() as Node3D
	if hero == null:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	var basis: Basis = camera.global_basis if camera != null else Basis.IDENTITY
	global_transform = Transform3D(basis, hero.global_position + Vector3.UP * _height)
