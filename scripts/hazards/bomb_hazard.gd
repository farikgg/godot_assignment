class_name BombHazard
extends Hazard

@export var fuse_time: float = 2.0
@export var blast_radius: float = 2.5
@export var blast_damage: int = 2
@export var explosion_sound: AudioStream

const FLASH_COLOR: Color = Color(0.94902, 0.701961, 0.239216)
const FLASH_TIME: float = 0.35

var _exploded: bool = false

func _ready() -> void:
	super._ready()

# Fuse starts on the first landing (Unity's Invoke): a one-shot Timer that respects pause.
func _on_landed() -> void:
	var fuse := Timer.new()
	fuse.one_shot = true
	fuse.wait_time = fuse_time
	fuse.timeout.connect(explode)
	add_child(fuse)
	fuse.start()

func hit_by_weapon(_damage: int = 1) -> void:
	explode()

func explode() -> void:
	if _exploded:
		return
	_exploded = true
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player != null and player.global_position.distance_to(global_position) <= blast_radius:
		var health: Health = player.get_node_or_null("Health") as Health
		if health == null:
			push_error("BombHazard: player has no Health child")
		else:
			health.take_damage(blast_damage)
	_spawn_flash()
	Sfx.play(explosion_sound, self)
	queue_free()

func _spawn_flash() -> void:
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	var flash := Node3D.new()
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = FLASH_COLOR
	sphere.material = material
	mesh.mesh = sphere
	flash.add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = FLASH_COLOR
	light.light_energy = 6.0
	light.omni_range = blast_radius * 2.0
	flash.add_child(light)
	parent.add_child(flash)
	flash.global_position = global_position
	var tween: Tween = flash.create_tween().set_parallel(true)
	tween.tween_property(mesh, "scale", Vector3.ONE * blast_radius * 2.0, FLASH_TIME)
	tween.tween_property(material, "albedo_color:a", 0.0, FLASH_TIME)
	tween.tween_property(light, "light_energy", 0.0, FLASH_TIME)
	tween.chain().tween_callback(flash.queue_free)
