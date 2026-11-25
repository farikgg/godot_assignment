class_name BombHazard
extends Hazard

## Fuse, blast radius and damage (resources/hazards/bomb.tres).
@export var data: HazardData
@export var explosion_sound: AudioStream
## Particle burst (with its own flash light) spawned on explosion.
@export var explosion_fx: PackedScene

var _exploded: bool = false

func _ready() -> void:
	super._ready()
	if data == null:
		push_error("BombHazard: no HazardData, it will not explode")

# Fuse starts on the first landing (Unity's Invoke): a one-shot Timer that respects pause.
func _on_landed() -> void:
	if data == null:
		return
	var fuse := Timer.new()
	fuse.one_shot = true
	fuse.wait_time = data.fuse_time
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
	if data != null and player != null and player.global_position.distance_to(global_position) <= data.blast_radius:
		var health: Health = player.get_node_or_null("Health") as Health
		if health == null:
			push_error("BombHazard: player has no Health child")
		else:
			health.take_damage(data.damage)
	_spawn_flash()
	Sfx.play_3d(explosion_sound, self, false)
	queue_free()

func _spawn_flash() -> void:
	if explosion_fx == null:
		return
	var fx: Node3D = explosion_fx.instantiate() as Node3D
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	parent.add_child(fx)
	fx.global_position = global_position
