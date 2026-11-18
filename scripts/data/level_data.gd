class_name LevelData
extends Resource
## One level of the campaign: what the level select shows, how levels unlock, and what the level
## spawns at start (enemies, cave-in) and needs to be won. The scene keeps geometry, coins,
## pickups, traps, gate and exit, and the Marker3D points the spawns refer to.

enum Goal {
	## Reach the exit (with at least coins_required gold).
	EXIT,
	## Defeat the boss (an EnemySpawn whose data is BossData).
	BOSS,
}

## Save-file id; never rename once players have saves.
@export var id: StringName
## Level select and the start-of-level toast, e.g. «Уровень 1 — Верхние залы».
@export var title: String
@export_file("*.tscn") var scene_path: String
## Open from the first start (the campaign's first level).
@export var unlocked_by_default: bool = false
## Completing this level unlocks it and "next" goes there; empty = the run ends on the win screen.
@export var next_level_id: StringName
## Target time shown next to the best time; 0 = no target.
@export var par_time_sec: float = 0.0

@export_group("Content")
@export var goal: Goal = Goal.EXIT
## Gold needed before the exit lets the hero through (EXIT goal only); 0 = none.
@export var coins_required: int = 0
@export var enemy_spawns: Array[EnemySpawn] = []
## Cave-in of the level; empty = none.
@export var spawner: SpawnerData
## Marker3D the cave-in is centred on.
@export var spawner_marker: StringName

## Problems in the data itself (marker names are checked when the scene loads); empty = fine.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if coins_required < 0:
		problems.append("negative coins_required")
	var has_boss: bool = false
	for i in enemy_spawns.size():
		var spawn: EnemySpawn = enemy_spawns[i]
		if spawn == null:
			problems.append("enemy_spawns[%d] is empty" % i)
			continue
		for problem in spawn.validate():
			problems.append("enemy_spawns[%d]: %s" % [i, problem])
		has_boss = has_boss or spawn.data is BossData
	if goal == Goal.BOSS and not has_boss:
		problems.append("goal BOSS but no spawn has BossData")
	if spawner != null:
		if spawner_marker == &"":
			problems.append("spawner set but no spawner_marker")
		for problem in spawner.validate():
			problems.append("spawner: %s" % problem)
	return problems
