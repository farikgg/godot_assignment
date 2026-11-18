class_name PlayerData
extends Resource
## The hero's balance (resources/player.tres). Defaults are 0 on purpose: the numbers live in the .tres.

@export_group("Movement")
@export var move_speed: float = 0.0  # m/s
## How fast the speed changes towards the input.
@export var acceleration: float = 0.0  # m/s²
@export var jump_velocity: float = 0.0  # m/s

@export_group("Health")
## Also the number of hearts on the HUD.
@export var max_hp: int = 0
## After a hit the hero blinks and cannot be hurt for this long.
@export var invincible_time: float = 0.0  # s
## HP lost by touching a saw or a trap (bodies in group `enemy` that are not an Enemy).
@export var trap_contact_damage: int = 0  # HP

@export_group("Knockback")
@export var knockback_speed: float = 0.0  # m/s, horizontal
@export var knockback_lift: float = 0.0  # m/s, upwards
## Input is ignored for this long after a hit so the knockback is visible.
@export var knockback_time: float = 0.0  # s

@export_group("Sword")
@export var sword_damage: int = 0  # HP per hit
@export var sword_cooldown: float = 0.0  # s between swings
## Centre of the slash hitbox in front of the hero.
@export var sword_reach: float = 0.0  # m

func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if move_speed <= 0.0 or acceleration <= 0.0 or jump_velocity <= 0.0:
		problems.append("move_speed, acceleration and jump_velocity must be above 0")
	if max_hp <= 0:
		problems.append("max_hp must be above 0")
	if sword_damage <= 0 or sword_cooldown < 0.0:
		problems.append("sword_damage must be above 0 and sword_cooldown not negative")
	if invincible_time < 0.0 or knockback_time < 0.0:
		problems.append("times must not be negative")
	return problems
