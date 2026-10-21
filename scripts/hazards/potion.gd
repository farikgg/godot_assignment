class_name Potion
extends Hazard
## Healing potion: lying on a level or dropped by the cave-in. It is picked up through its own
## Area3D (PickupZone), not through RigidBody contacts: a resting body falls asleep and stops
## reporting them, so walking into it did nothing. At full health it stays where it is.
## Lying on the floor it is frozen (the level's potion from the start, a dropped one once it lands).

const FULL_HEALTH_TEXT: String = "Здоровье полное"

@export var heal_amount: int = 1
@export_file("*.ogg", "*.wav") var heal_sound_path: String = "res://assets/Audio/sfx/heal.wav"

@onready var _pickup_zone: Area3D = $PickupZone

var _heal_sound: AudioStream
var _taken: bool = false

func _ready() -> void:
	super._ready()
	_heal_sound = Sfx.load_stream(heal_sound_path)
	_pickup_zone.body_entered.connect(_on_pickup_zone_body_entered)

# touching the rigid body itself does nothing; the zone does the work
func _on_hit_player(_health: Health) -> void:
	pass

# once on the floor it is a static pickup: the hero can't kick it away (or into a pit)
func _on_landed() -> void:
	set_deferred("freeze", true)

func _on_pickup_zone_body_entered(body: Node3D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	var health: Health = body.get_node_or_null("Health") as Health
	if health == null:
		push_error("Potion: player %s has no Health child" % body.name)
		return
	if health.is_dead():
		return
	if health.current >= health.max_hp:
		# duck-typed: a prop must not pull level.gd (and its autoloads) into its own compilation
		var level: Node = get_tree().current_scene
		if level != null and level.has_method("show_hint"):
			level.call("show_hint", FULL_HEALTH_TEXT)
		return
	_taken = true
	health.heal(heal_amount)
	Sfx.play(_heal_sound, self)
	queue_free()
