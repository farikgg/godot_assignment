class_name LevelData
extends Resource
## One level of the campaign: what the level select shows and how levels unlock.
## The scene keeps geometry, coins, pickups and spawn markers.

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
