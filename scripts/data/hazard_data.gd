class_name HazardData
extends Resource
## Numbers of one falling or dropped hazard (resources/hazards/*.tres). A field a hazard
## does not use stays 0.

## HP lost by the hero on a hit (rock, fire rain) or inside the blast (bomb).
@export var damage: int = 0  # HP
## Falling speed (fire rain).
@export var speed: float = 0.0  # m/s

@export_group("Bomb")
## The bomb explodes this long after it first lands.
@export var fuse_time: float = 0.0  # s
@export var blast_radius: float = 0.0  # m

@export_group("Fire rain")
## The warning circle grows for this long before the drop falls.
@export var warning_time: float = 0.0  # s
## The drop hurts the hero within this distance of its spot.
@export var impact_radius: float = 0.0  # m
