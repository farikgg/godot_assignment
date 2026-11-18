class_name Rock
extends Hazard

## Damage on a hit (resources/hazards/rock.tres).
@export var data: HazardData
## Dust puff spawned where the rock first lands.
@export var landing_fx: PackedScene

func _ready() -> void:
	super._ready()
	if data == null:
		push_error("Rock: no HazardData, it is harmless")

func _on_hit_player(health: Health) -> void:
	health.take_damage(data.damage if data != null else 0)
	queue_free()

func _on_landed() -> void:
	if landing_fx == null:
		return
	var fx: Node3D = landing_fx.instantiate() as Node3D
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	parent.add_child(fx)
	fx.global_position = global_position
