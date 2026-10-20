class_name EnemyData
extends Resource
## Stats and model of one kind of rank-and-file enemy (skeleton, zombie, vampire…).

@export var display_name: String
@export var model: PackedScene
## Uniform scale of the model inside the enemy's Visual node.
@export var model_scale: float = 1.4
@export var max_hp: int = 2

@export_group("Movement")
@export var walk_speed: float = 1.5
@export var run_speed: float = 3.0

@export_group("Senses")
## Starts the chase when the hero is this close and in plain view.
@export var sight_radius: float = 6.0
## Gives up and returns to patrol when the hero is farther than this.
@export var lose_radius: float = 9.0

@export_group("Attack")
@export var attack_range: float = 1.0
@export var attack_damage: int = 1
## Wind-up before the blow lands, seconds (the attack clip is slowed to match).
@export var attack_windup: float = 0.5
## Pause after the blow before the next decision, seconds.
@export var attack_cooldown: float = 1.0
