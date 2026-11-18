class_name EnemySpawn
extends Resource
## One enemy a level spawns at start: which scene, with which numbers, on which Marker3D.

## Scene whose root extends Enemy (minion, shooter, charger, boss).
@export var scene: PackedScene
## Its balance; must be the EnemyData subclass the scene expects (BossData for the boss…).
@export var data: EnemyData
## Name of a Marker3D in the level scene; the enemy appears at its position.
@export var marker: StringName
## Minion only: second patrol point relative to the spawn point.
@export var patrol_offset: Vector3 = Vector3.ZERO  # m
## Direction the model looks at the start: 0 = +Z (south), 90 = +X (east), 180 = -Z, 270 = -X.
@export var start_yaw_degrees: float = 0.0

## Problems that make the spawn unusable; empty = fine.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if scene == null:
		problems.append("no scene")
	if data == null:
		problems.append("no data")
	if marker == &"":
		problems.append("no marker name")
	return problems
