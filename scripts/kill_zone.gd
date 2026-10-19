extends Area3D
## Wide trigger below a level: the player falling into a pit dies at once, invincible or not.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var health: Health = body.get_node_or_null("Health") as Health
	if health == null:
		push_error("KillZone: player %s has no Health child" % body.name)
		return
	health.kill()
