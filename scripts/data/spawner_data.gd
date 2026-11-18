class_name SpawnerData
extends Resource
## A cave-in: what falls, how often, how many at once and over which area (resources/spawners/*.tres).

## Any scenes whose root extends Hazard.
@export var hazard_scenes: Array[PackedScene] = []
## Relative chance of each entry in hazard_scenes (same length, sum > 0; 0 = never).
@export var spawn_weights: Array[float] = []
@export var interval: float = 0.0  # s between drops
@export var max_alive: int = 0
## Spawn rectangle on the floor, centred on the spawner.
@export var area_size: Vector2 = Vector2.ZERO  # m
## How long the warning shadow grows before the drop.
@export var telegraph_time: float = 0.0  # s

## Problems that would stop the spawner; empty = fine.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if hazard_scenes.is_empty():
		problems.append("hazard_scenes is empty")
	if spawn_weights.size() != hazard_scenes.size():
		problems.append("%d weights for %d scenes" % [spawn_weights.size(), hazard_scenes.size()])
	var total: float = 0.0
	for weight in spawn_weights:
		if weight < 0.0:
			problems.append("negative weight %s" % weight)
		total += maxf(weight, 0.0)
	if total <= 0.0:
		problems.append("spawn weights sum to 0")
	for scene in hazard_scenes:
		if scene == null:
			problems.append("empty slot in hazard_scenes")
	if interval <= 0.0 or max_alive <= 0:
		problems.append("interval and max_alive must be above 0")
	if area_size.x <= 0.0 or area_size.y <= 0.0:
		problems.append("area_size must be above 0")
	return problems
