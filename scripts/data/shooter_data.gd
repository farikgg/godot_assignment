class_name ShooterData
extends EnemyData
## Numbers of the ranged skeleton (resources/enemies/shooter*.tres).

## Sight and shot range; capped at 8 m so a shot never starts outside the camera picture.
@export_range(1.0, 8.0) var fire_range: float = 1.0  # m
@export var bolt_speed: float = 0.0  # m/s
@export var bolt_damage: int = 0  # HP

@export_group("Timing")
## Wind-up: the laser is on for this long before the shot.
@export var aim_time: float = 0.0  # s
## Recovery: stands still after the shot.
@export var fire_time: float = 0.0  # s
## Then waits this long before it may aim again.
@export var cooldown_time: float = 0.0  # s

@export_group("Keep distance")
## Backs away when the hero is closer than this…
@export var retreat_distance: float = 0.0  # m
## …until they are this far away,
@export var keep_distance: float = 0.0  # m
## or this much time has passed.
@export var retreat_max_time: float = 0.0  # s
@export var retreat_speed: float = 0.0  # m/s

func validate() -> PackedStringArray:
	var problems: PackedStringArray = super()
	if bolt_speed <= 0.0:
		problems.append("bolt_speed must be above 0")
	if aim_time <= 0.0 or fire_time <= 0.0 or cooldown_time <= 0.0 or retreat_max_time <= 0.0:
		problems.append("times must be above 0")
	if retreat_distance > keep_distance:
		problems.append("retreat_distance is above keep_distance")
	return problems
