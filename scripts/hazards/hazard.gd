class_name Hazard
extends RigidBody3D

## Seconds before the hazard removes itself.
@export var lifetime: float = 6.0

var _landed: bool = false

func _ready() -> void:
	add_to_group("hazard")
	# для сигналов урона и приземления
	# так как в RigidBody3D body_entered не работает
	contact_monitor = true
	max_contacts_reported = maxi(max_contacts_reported, 4)
	# falls from ~12 m: without CCD it can tunnel through the 0.2 m floor
	continuous_cd = true
	body_entered.connect(_on_body_entered)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = lifetime
	timer.autostart = true
	timer.timeout.connect(queue_free)
	add_child(timer)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var health: Health = body.get_node_or_null("Health") as Health
		if health == null:
			push_error("Hazard: player %s has no Health child" % body.name)
			return
		_on_hit_player(health)
	elif not _landed:
		_landed = true
		_on_landed()

## вызывается при контакте с игроком
func _on_hit_player(_health: Health) -> void:
	pass

## все что угодно кроме игрока
func _on_landed() -> void:
	pass

## вызывается при ударе мечом(игроком)
func hit_by_weapon(_damage: int = 1) -> void:
	queue_free()
