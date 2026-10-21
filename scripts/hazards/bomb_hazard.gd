class_name BombHazard
extends Hazard

@export var fuse_time: float = 2.0
@export var blast_radius: float = 2.5
@export var blast_damage: int = 2
@export_file("*.ogg", "*.wav") var explosion_sound_path: String = "res://assets/Audio/sfx/explosion.wav"
## Particle burst (with its own flash light) spawned on explosion.
@export var explosion_fx: PackedScene

var _exploded: bool = false
var _explosion_sound: AudioStream

func _ready() -> void:
	super._ready()
	_explosion_sound = Sfx.load_stream(explosion_sound_path)

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
	Sfx.play(_explosion_sound, self)
	queue_free()

func _spawn_flash() -> void:
	if explosion_fx == null:
		return
	var fx: Node3D = explosion_fx.instantiate() as Node3D
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	parent.add_child(fx)
	fx.global_position = global_position
