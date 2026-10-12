class_name Rock
extends Hazard

@export var damage: int = 1
## Dust puff spawned where the rock first lands.
@export var landing_fx: PackedScene

func _ready() -> void:
	super._ready()

func _on_hit_player(health: Health) -> void:
	health.take_damage(damage)
	queue_free()

func _on_landed() -> void:
	if landing_fx == null:
		return
	var fx: Node3D = landing_fx.instantiate() as Node3D
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	parent.add_child(fx)
	fx.global_position = global_position
