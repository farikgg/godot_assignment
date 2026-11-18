class_name LevelCatalog
extends Resource
## Every level, in level-select order. Unlocking follows LevelData.next_level_id, not this order.

@export var levels: Array[LevelData] = []

func get_by_id(id: StringName) -> LevelData:
	var index: int = index_of_id(id)
	return levels[index] if index != -1 else null

func index_of_id(id: StringName) -> int:
	for i in levels.size():
		if levels[i] != null and levels[i].id == id:
			return i
	return -1

func index_of_scene(scene_path: String) -> int:
	var wanted: String = resolve_path(scene_path)
	for i in levels.size():
		if levels[i] != null and resolve_path(levels[i].scene_path) == wanted:
			return i
	return -1

## The editor may store a picked file as "uid://…"; scene_file_path is always "res://…".
static func resolve_path(path: String) -> String:
	if path.begins_with("uid://"):
		var uid: int = ResourceUID.text_to_id(path)
		if ResourceUID.has_id(uid):
			return ResourceUID.get_id_path(uid)
	return path

## Problems that would break the flow or the save, one message each; empty = fine.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var seen: Array[StringName] = []
	var any_default: bool = false
	for i in levels.size():
		var level: LevelData = levels[i]
		if level == null:
			problems.append("entry %d is empty" % i)
			continue
		if level.id == &"":
			problems.append("entry %d has no id" % i)
		elif seen.has(level.id):
			problems.append("id '%s' is used twice" % level.id)
		seen.append(level.id)
		if not ResourceLoader.exists(level.scene_path):
			problems.append("'%s': scene '%s' not found" % [level.id, level.scene_path])
		if level.par_time_sec < 0.0:
			problems.append("'%s': negative par_time_sec" % level.id)
		any_default = any_default or level.unlocked_by_default
	for level in levels:
		if level != null and level.next_level_id != &"" and index_of_id(level.next_level_id) == -1:
			problems.append("'%s': next_level_id '%s' is not in the catalog" % [level.id, level.next_level_id])
	if not levels.is_empty() and not any_default:
		problems.append("no level is unlocked_by_default, nothing could be played")
	return problems
