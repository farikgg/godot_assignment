class_name EnemyData
extends Resource
## Stats and model of one kind of enemy (skeleton, zombie, vampire…). Subclasses add the numbers
## of the special enemies (BossData, ShooterData, ChargerData). Defaults are 0 on purpose: every
## number lives in the .tres files under resources/enemies/.

@export var display_name: String
## Only the Minion builds its body from this; Boss, Shooter and Charger carry their model in the scene.
@export var model: PackedScene
## Uniform scale of the model inside the enemy's Visual node.
@export var model_scale: float = 1.0
@export var max_hp: int = 0
## After a hit the enemy cannot be hurt again for this long.
@export var invincible_time: float = 0.0  # s
## HP the hero loses by touching the enemy's body (0 = harmless to touch).
@export var contact_damage: int = 0  # HP

@export_group("Movement")
@export var walk_speed: float = 0.0  # m/s
@export var run_speed: float = 0.0  # m/s
## Push away from the hero after a sword hit (0 = does not budge).
@export var knockback_speed: float = 0.0  # m/s
@export var knockback_time: float = 0.0  # s

@export_group("Senses")
## View range: the chase starts when the hero is this close, inside the view cone and not behind a wall.
@export var sight_radius: float = 0.0  # m
## Gives up and returns to patrol when the hero is farther than this.
@export var lose_radius: float = 0.0  # m
## Width of the view cone.
@export var fov_degrees: float = 0.0

@export_group("Attack")
@export var attack_range: float = 0.0  # m
@export var attack_damage: int = 0  # HP
## Wind-up before the blow lands (the attack clip is slowed to match).
@export var attack_windup: float = 0.0  # s
## After the blow the enemy stands still and open for this long.
@export var attack_recovery: float = 0.0  # s
## After the recovery it may move, but not start a new attack, for this long.
@export var attack_cooldown: float = 0.0  # s
## The blow still lands this far beyond attack_range (the hero stepping back a little).
@export var strike_reach_margin: float = 0.0  # m
## The blow misses a hero this much higher or lower (jumped, or on a ledge).
@export var strike_height: float = 0.0  # m

## Problems that make the enemy unusable; empty = fine.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if max_hp <= 0:
		problems.append("max_hp must be above 0")
	if invincible_time < 0.0 or knockback_time < 0.0:
		problems.append("times must not be negative")
	if contact_damage < 0:
		problems.append("contact_damage must not be negative")
	return problems
