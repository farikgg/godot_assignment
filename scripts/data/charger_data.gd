class_name ChargerData
extends EnemyData
## Numbers of the dashing zombie (resources/enemies/charger.tres).

## Winds up when the hero is seen this close…
@export var trigger_range: float = 0.0  # m
## …but not closer than this (a dash from point-blank range can't be dodged).
@export var min_trigger_distance: float = 0.0  # m

@export_group("Timing")
@export var windup_time: float = 0.0  # s
## Stands dazed after hitting a wall or the hero.
@export var stun_time: float = 0.0  # s

@export_group("Dash")
@export var dash_speed: float = 0.0  # m/s
## The dash ends after this distance even when it hits nothing.
@export var dash_distance: float = 0.0  # m
@export var dash_damage: int = 0  # HP
## The dash hits the hero this close (flat distance)…
@export var hit_reach: float = 0.0  # m
## …and at most this much above or below.
@export var hit_height: float = 0.0  # m

func validate() -> PackedStringArray:
	var problems: PackedStringArray = super()
	if dash_speed <= 0.0 or dash_distance <= 0.0:
		problems.append("dash_speed and dash_distance must be above 0")
	if windup_time <= 0.0 or stun_time <= 0.0:
		problems.append("windup_time and stun_time must be above 0")
	if min_trigger_distance > trigger_range:
		problems.append("min_trigger_distance is above trigger_range")
	return problems
