class_name BossData
extends EnemyData
## Numbers of the arena guardian (resources/enemies/boss.tres).

@export_group("Timing")
@export var idle_time: float = 0.0  # s
@export var telegraph_time: float = 0.0  # s
@export var rest_time: float = 0.0  # s
## Telegraph and rest are multiplied by this in phase 2.
@export var enraged_time_scale: float = 1.0
## Phase 2 starts when HP drops to this share of max_hp or below.
@export_range(0.0, 1.0) var enrage_hp_fraction: float = 0.0
## The fight starts when the hero walks this far from their start, or after wake_delay seconds.
@export var wake_distance: float = 0.0  # m
@export var wake_delay: float = 0.0  # s

@export_group("Fan")
@export var fan_count: int = 0
@export var fan_spread_degrees: float = 0.0
@export var enraged_fan_count: int = 0
@export var enraged_fan_spread_degrees: float = 0.0
@export var fan_volleys: int = 0
@export var volley_gap: float = 0.0  # s
@export var fireball_speed: float = 0.0  # m/s
@export var fireball_damage: int = 0  # HP

@export_group("Rain")
@export var rain_count: int = 0
@export var enraged_rain_count: int = 0
## Rain spots lie this far from the hero (the first one is right under them).
@export var rain_min_radius: float = 0.0  # m
@export var rain_max_radius: float = 0.0  # m
## How long the boss stays in ATTACK after calling the rain.
@export var rain_attack_time: float = 0.0  # s

func validate() -> PackedStringArray:
	var problems: PackedStringArray = super()
	if fan_count <= 0 or enraged_fan_count <= 0 or fan_volleys <= 0:
		problems.append("fan counts and volleys must be above 0")
	if fireball_speed <= 0.0:
		problems.append("fireball_speed must be above 0")
	if rain_count <= 0 or enraged_rain_count <= 0:
		problems.append("rain counts must be above 0")
	if rain_min_radius > rain_max_radius:
		problems.append("rain_min_radius is above rain_max_radius")
	if idle_time <= 0.0 or telegraph_time <= 0.0 or rest_time <= 0.0 or rain_attack_time <= 0.0:
		problems.append("state times must be above 0")
	return problems
