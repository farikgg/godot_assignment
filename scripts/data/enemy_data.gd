class_name EnemyData
extends Resource
## Stats and model of one kind of rank-and-file enemy (skeleton, zombie, vampire…).

@export var display_name: String
@export var model: PackedScene
## Uniform scale of the model inside the enemy's Visual node.
@export var model_scale: float = 1.4
@export var max_hp: int = 2

@export_group("Movement")
@export var walk_speed: float = 1.5  # m/s
@export var run_speed: float = 3.0  # m/s

@export_group("Senses")
## View range: the chase starts when the hero is this close, inside the view cone and not behind a wall.
@export var sight_radius: float = 6.0  # m
## Gives up and returns to patrol when the hero is farther than this.
@export var lose_radius: float = 9.0  # m

@export_group("Attack")
@export var attack_range: float = 1.0  # m
@export var attack_damage: int = 1  # HP
## Wind-up before the blow lands (the attack clip is slowed to match).
@export var attack_windup: float = 0.5  # s
## After the blow the enemy stands still and open for this long.
@export var attack_recovery: float = 0.4  # s
## After the recovery it may move, but not start a new attack, for this long.
@export var attack_cooldown: float = 0.6  # s
## The blow still lands this far beyond attack_range (the hero stepping back a little).
@export var strike_reach_margin: float = 0.4  # m
## The blow misses a hero this much higher or lower (jumped, or on a ledge).
@export var strike_height: float = 1.2  # m
