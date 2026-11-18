extends Node
## Autoload SaveGame: the single JSON save in user:// (progress, records, heroes, settings).
## load_game() checks every field on its own and falls back to that field's default with a
## warning, so a damaged file costs only the broken fields and never stops the game.
## Writes go to a .tmp file first and are renamed over the save, so a crash mid-write leaves the
## previous save intact.

signal changed

const SAVE_PATH: String = "user://save.json"
const TMP_SUFFIX: String = ".tmp"
const VERSION: int = 1
const DEFAULT_NAME: String = "Player"
## Same limit as the name field in the main menu.
const MAX_NAME_LENGTH: int = 15
const MAX_COINS: int = 1_000_000
## A level record longer than a day is treated as broken.
const MAX_TIME_SEC: float = 86_400.0
const DEFAULT_VOLUME: float = 1.0
## Larger files are not read at all: a save is a few hundred bytes.
const MAX_FILE_BYTES: int = 1_048_576
## Settings sliders fire on every step; their saves are gathered into one write after this pause.
const SAVE_DEBOUNCE_SEC: float = 0.5
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
const JSON_INDENT: String = "\t"
## Floats above 2^53 can no longer hold every integer exactly.
const MAX_EXACT_FLOAT_INT: float = 9_007_199_254_740_992.0

const KEY_VERSION: String = "version"
const KEY_PLAYER_NAME: String = "player_name"
const KEY_SELECTED_HERO: String = "selected_hero"
const KEY_UNLOCKED_HEROES: String = "unlocked_heroes"
const KEY_UNLOCKED_LEVELS: String = "unlocked_levels"
const KEY_BEST_SCORE: String = "best_score"
const KEY_BEST_TIME: String = "best_time_sec"
const KEY_BEST_TOTAL: String = "best_total"
const KEY_TOTAL_COINS: String = "total_coins"
const KEY_MUSIC_VOLUME: String = "music_volume"
const KEY_SFX_VOLUME: String = "sfx_volume"
const KNOWN_KEYS: Array[String] = [
	KEY_VERSION, KEY_PLAYER_NAME, KEY_SELECTED_HERO, KEY_UNLOCKED_HEROES, KEY_UNLOCKED_LEVELS,
	KEY_BEST_SCORE, KEY_BEST_TIME, KEY_BEST_TOTAL, KEY_TOTAL_COINS, KEY_MUSIC_VOLUME, KEY_SFX_VOLUME,
]

## Tests point this at a scratch file so the real save is untouched.
var save_path: String = SAVE_PATH

var player_name: String = DEFAULT_NAME
var selected_hero: StringName = &""
var unlocked_heroes: Array[StringName] = []
var unlocked_levels: Array[StringName] = []
## Most coins collected in one completion of each level.
var best_score: Dictionary[StringName, int] = {}
## Fastest completion of each level, seconds.
var best_time_sec: Dictionary[StringName, float] = {}
## Most coins over a whole run from the first level to the win screen.
var best_total: int = 0
## Every coin banked from completed levels, kept for the future shop.
var total_coins: int = 0
var music_volume: float = DEFAULT_VOLUME
var sfx_volume: float = DEFAULT_VOLUME

var _save_timer: Timer
## Bus levels from default_bus_layout.tres: the sliders scale on top of this mix.
var _bus_base_db: Dictionary[StringName, float] = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE_SEC
	_save_timer.ignore_time_scale = true
	_save_timer.timeout.connect(save_game)
	add_child(_save_timer)
	for bus in [MUSIC_BUS, SFX_BUS]:
		var index: int = AudioServer.get_bus_index(bus)
		if index != -1:
			_bus_base_db[bus] = AudioServer.get_bus_volume_db(index)
	load_game()

func _notification(what: int) -> void:
	# Android may kill a paused app without another callback: write now. Only save here; the
	# game's pause state belongs to the pause menu.
	if what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()

# --- loading ---------------------------------------------------------------------------------

## Reads the save. Always leaves a valid state: defaults for anything missing or broken.
## Returns OK when the file was read (individual fields may still have been replaced).
func load_game() -> Error:
	var result: Error = OK
	var data: Variant = _read_json(save_path)
	if data == null:
		# a crash between writing the .tmp file and the rename leaves only the .tmp
		data = _read_json(save_path + TMP_SUFFIX, false)
		if data != null:
			push_warning("SaveGame: %s unusable, recovered from %s%s" % [save_path, save_path, TMP_SUFFIX])
	if data is Dictionary:
		_apply_data(data as Dictionary)
	else:
		if data != null:
			push_warning("SaveGame: %s is not a JSON object, using defaults" % save_path)
		_set_defaults()
		result = ERR_FILE_UNRECOGNIZED if FileAccess.file_exists(save_path) else ERR_FILE_NOT_FOUND
	_apply_audio()
	changed.emit()
	return result

# null when the file is missing, unreadable or not JSON (with a warning except for a missing file)
func _read_json(path: String, warn_missing: bool = false) -> Variant:
	if not FileAccess.file_exists(path):
		if warn_missing:
			push_warning("SaveGame: %s not found" % path)
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SaveGame: cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return null
	if file.get_length() > MAX_FILE_BYTES:
		push_warning("SaveGame: %s is %d bytes, too large for a save" % [path, file.get_length()])
		return null
	var text: String = file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		push_warning("SaveGame: %s is empty" % path)
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("SaveGame: %s is not valid JSON (line %d: %s)"
			% [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data

func _set_defaults() -> void:
	_set_progress_defaults()
	player_name = DEFAULT_NAME
	music_volume = DEFAULT_VOLUME
	sfx_volume = DEFAULT_VOLUME

func _set_progress_defaults() -> void:
	unlocked_heroes = _default_heroes()
	selected_hero = _default_selected_hero()
	unlocked_levels = _default_levels()
	best_score = {}
	best_time_sec = {}
	best_total = 0
	total_coins = 0

func _apply_data(data: Dictionary) -> void:
	_set_defaults()
	for key: Variant in data.keys():
		if not (key is String and KNOWN_KEYS.has(key)):
			push_warning("SaveGame: unknown field '%s' ignored" % str(key))

	var version: int = _read_int(data, KEY_VERSION, VERSION, 1, VERSION)
	if version != VERSION:
		push_warning("SaveGame: save version %d, reading it as version %d" % [version, VERSION])

	var name_value: Variant = _read_typed(data, KEY_PLAYER_NAME, TYPE_STRING)
	if name_value != null:
		player_name = _clean_name(name_value as String)

	var known_heroes: Array[StringName] = _known_heroes()
	var heroes: Variant = _read_id_list(data, KEY_UNLOCKED_HEROES, known_heroes)
	if heroes != null:
		unlocked_heroes = _merged(heroes as Array[StringName], _default_heroes())
	var hero_value: Variant = _read_typed(data, KEY_SELECTED_HERO, TYPE_STRING)
	if hero_value != null:
		var hero := StringName(hero_value as String)
		if unlocked_heroes.has(hero):
			selected_hero = hero
		else:
			push_warning("SaveGame: selected_hero '%s' is unknown or locked, using '%s'" % [hero, selected_hero])
	if not unlocked_heroes.has(selected_hero):
		selected_hero = _default_selected_hero()

	var known_levels: Array[StringName] = _known_levels()
	var levels: Variant = _read_id_list(data, KEY_UNLOCKED_LEVELS, known_levels)
	if levels != null:
		unlocked_levels = _merged(levels as Array[StringName], _default_levels())

	var scores: Variant = _read_typed(data, KEY_BEST_SCORE, TYPE_DICTIONARY)
	if scores != null:
		for id: StringName in _valid_id_map(scores as Dictionary, KEY_BEST_SCORE, known_levels):
			var coins: Variant = _as_int((scores as Dictionary)[String(id)], 0, MAX_COINS)
			if coins == null:
				push_warning("SaveGame: best_score.%s is not a whole number 0..%d, dropped" % [id, MAX_COINS])
			else:
				best_score[id] = coins as int

	var times: Variant = _read_typed(data, KEY_BEST_TIME, TYPE_DICTIONARY)
	if times != null:
		for id: StringName in _valid_id_map(times as Dictionary, KEY_BEST_TIME, known_levels):
			var seconds: Variant = _as_float((times as Dictionary)[String(id)], 0.0, MAX_TIME_SEC)
			if seconds == null or (seconds as float) <= 0.0:
				push_warning("SaveGame: best_time_sec.%s is not a time in (0, %d] s, dropped" % [id, MAX_TIME_SEC])
			else:
				best_time_sec[id] = seconds as float

	best_total = _read_int(data, KEY_BEST_TOTAL, 0, 0, MAX_COINS)
	total_coins = _read_int(data, KEY_TOTAL_COINS, 0, 0, MAX_COINS)
	music_volume = _read_float(data, KEY_MUSIC_VOLUME, DEFAULT_VOLUME, 0.0, 1.0)
	sfx_volume = _read_float(data, KEY_SFX_VOLUME, DEFAULT_VOLUME, 0.0, 1.0)

# the value when the key exists with the right JSON type, else null (with a warning)
func _read_typed(data: Dictionary, key: String, type: Variant.Type) -> Variant:
	if not data.has(key):
		push_warning("SaveGame: field '%s' missing, using the default" % key)
		return null
	var value: Variant = data[key]
	if typeof(value) != type:
		push_warning("SaveGame: field '%s' has type %s, expected %s; using the default"
			% [key, type_string(typeof(value)), type_string(type)])
		return null
	return value

func _read_int(data: Dictionary, key: String, default: int, min_value: int, max_value: int) -> int:
	if not data.has(key):
		push_warning("SaveGame: field '%s' missing, using the default" % key)
		return default
	var value: Variant = _as_int(data[key], min_value, max_value)
	if value == null:
		push_warning("SaveGame: field '%s' = %s is not a whole number %d..%d; using %d"
			% [key, str(data[key]), min_value, max_value, default])
		return default
	return value as int

func _read_float(data: Dictionary, key: String, default: float, min_value: float, max_value: float) -> float:
	if not data.has(key):
		push_warning("SaveGame: field '%s' missing, using the default" % key)
		return default
	var value: Variant = _as_float(data[key], min_value, max_value)
	if value == null:
		push_warning("SaveGame: field '%s' = %s is not a number %s..%s; using %s"
			% [key, str(data[key]), min_value, max_value, default])
		return default
	return value as float

# JSON has only floats: 3.0 is accepted as 3, 3.5 / NaN / inf are not
func _as_int(value: Variant, min_value: int, max_value: int) -> Variant:
	var number: int
	if value is int:
		number = value
	elif value is float:
		var f: float = value
		if not is_finite(f) or f != floorf(f) or absf(f) > MAX_EXACT_FLOAT_INT:
			return null
		number = int(f)
	else:
		return null
	return number if number >= min_value and number <= max_value else null

func _as_float(value: Variant, min_value: float, max_value: float) -> Variant:
	if not (value is float or value is int):
		return null
	var number: float = float(value)
	if not is_finite(number) or number < min_value or number > max_value:
		return null
	return number

# a list of known ids without duplicates; null when the field itself is broken
func _read_id_list(data: Dictionary, key: String, known: Array[StringName]) -> Variant:
	var value: Variant = _read_typed(data, key, TYPE_ARRAY)
	if value == null:
		return null
	var result: Array[StringName] = []
	for entry: Variant in value as Array:
		if not entry is String:
			push_warning("SaveGame: %s entry %s is not a string, dropped" % [key, str(entry)])
			continue
		var id := StringName(entry as String)
		if not known.has(id):
			push_warning("SaveGame: %s has unknown id '%s', dropped" % [key, id])
		elif not result.has(id):
			result.append(id)
	return result

# ids of `map` that are known level ids; the rest is reported
func _valid_id_map(map: Dictionary, key: String, known: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for id_value: Variant in map.keys():
		var id := StringName(str(id_value))
		if known.has(id):
			result.append(id)
		else:
			push_warning("SaveGame: %s has unknown level id '%s', dropped" % [key, id])
	return result

func _merged(ids: Array[StringName], required: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = ids.duplicate()
	for id in required:
		if not result.has(id):
			result.append(id)
	return result

func _clean_name(value: String) -> String:
	var cleaned: String = value.strip_edges()
	if cleaned.length() > MAX_NAME_LENGTH:
		push_warning("SaveGame: player_name longer than %d characters, cut" % MAX_NAME_LENGTH)
		cleaned = cleaned.left(MAX_NAME_LENGTH)
	return cleaned if not cleaned.is_empty() else DEFAULT_NAME

# --- known ids -------------------------------------------------------------------------------

func _known_heroes() -> Array[StringName]:
	var ids: Array[StringName] = []
	for character in Roster.all():
		if character != null:
			ids.append(character.id)
	return ids

func _default_heroes() -> Array[StringName]:
	var ids: Array[StringName] = []
	for character in Roster.all():
		if character != null and character.unlocked_by_default:
			ids.append(character.id)
	# a roster with every hero locked would leave nobody to play
	if ids.is_empty() and Roster.first() != null:
		ids.append(Roster.first().id)
	return ids

func _default_selected_hero() -> StringName:
	var first: CharacterData = Roster.first()
	if first != null and unlocked_heroes.has(first.id):
		return first.id
	return unlocked_heroes[0] if not unlocked_heroes.is_empty() else &""

func _known_levels() -> Array[StringName]:
	return GameFlow.level_ids()

func _default_levels() -> Array[StringName]:
	return GameFlow.default_unlocked_level_ids()

# --- saving ----------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var scores: Dictionary = {}
	for id in best_score:
		scores[String(id)] = best_score[id]
	var times: Dictionary = {}
	for id in best_time_sec:
		times[String(id)] = best_time_sec[id]
	return {
		KEY_VERSION: VERSION,
		KEY_PLAYER_NAME: player_name,
		KEY_SELECTED_HERO: String(selected_hero),
		KEY_UNLOCKED_HEROES: _to_strings(unlocked_heroes),
		KEY_UNLOCKED_LEVELS: _to_strings(unlocked_levels),
		KEY_BEST_SCORE: scores,
		KEY_BEST_TIME: times,
		KEY_BEST_TOTAL: best_total,
		KEY_TOTAL_COINS: total_coins,
		KEY_MUSIC_VOLUME: music_volume,
		KEY_SFX_VOLUME: sfx_volume,
	}

## Writes the save now (a pending queued save is folded into this one).
func save_game() -> Error:
	if _save_timer != null:
		_save_timer.stop()
	var tmp_path: String = save_path + TMP_SUFFIX
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		push_warning("SaveGame: cannot write %s (%s)" % [tmp_path, error_string(open_error)])
		return open_error
	var stored: bool = file.store_string(JSON.stringify(to_dict(), JSON_INDENT))
	file.close()
	if not stored:
		push_warning("SaveGame: writing %s failed" % tmp_path)
		DirAccess.remove_absolute(tmp_path)
		return ERR_FILE_CANT_WRITE
	var error: Error = DirAccess.rename_absolute(tmp_path, save_path)
	if error != OK:
		# some file systems refuse to rename over an existing file
		DirAccess.remove_absolute(save_path)
		error = DirAccess.rename_absolute(tmp_path, save_path)
	if error != OK:
		push_warning("SaveGame: cannot move %s to %s (%s)" % [tmp_path, save_path, error_string(error)])
	return error

## Saves a moment later; repeated calls meanwhile cost one write.
func queue_save() -> void:
	if _save_timer != null and _save_timer.is_inside_tree():
		_save_timer.start()
	else:
		save_game()

func has_pending_save() -> bool:
	return _save_timer != null and not _save_timer.is_stopped()

## Clears progress (levels, records, coins, heroes) and saves; name and volumes stay.
func reset() -> void:
	_set_progress_defaults()
	save_game()
	changed.emit()

# --- progress --------------------------------------------------------------------------------

func is_level_unlocked(level_id: StringName) -> bool:
	return unlocked_levels.has(level_id)

func is_hero_unlocked(hero_id: StringName) -> bool:
	return unlocked_heroes.has(hero_id)

## A completed level: keeps the best coins and time, banks the coins, opens the level's
## next_level_id and saves at once.
func record_level_result(level_id: StringName, coins: int, time_sec: float) -> void:
	var level: LevelData = GameFlow.get_level(level_id)
	if level == null:
		push_warning("SaveGame: result for unknown level '%s' not recorded" % level_id)
		return
	if level.next_level_id != &"" and not unlocked_levels.has(level.next_level_id):
		unlocked_levels.append(level.next_level_id)
	var safe_coins: int = clampi(coins, 0, MAX_COINS)
	best_score[level_id] = maxi(best_score.get(level_id, 0), safe_coins)
	if is_finite(time_sec) and time_sec > 0.0 and time_sec <= MAX_TIME_SEC:
		best_time_sec[level_id] = minf(best_time_sec.get(level_id, MAX_TIME_SEC), time_sec)
	total_coins = mini(total_coins + safe_coins, MAX_COINS)
	save_game()
	changed.emit()

## A run that went from the first level to the win screen.
func record_run_total(coins: int) -> void:
	best_total = maxi(best_total, clampi(coins, 0, MAX_COINS))
	save_game()
	changed.emit()

# --- profile & settings ----------------------------------------------------------------------

func set_player_name(value: String) -> void:
	player_name = value.left(MAX_NAME_LENGTH)
	queue_save()
	changed.emit()

## False (and nothing changes) for an unknown or locked hero.
func set_selected_hero(hero_id: StringName) -> bool:
	if not unlocked_heroes.has(hero_id):
		push_warning("SaveGame: hero '%s' is unknown or locked" % hero_id)
		return false
	selected_hero = hero_id
	save_game()
	changed.emit()
	return true

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus(MUSIC_BUS, music_volume)
	queue_save()
	changed.emit()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus(SFX_BUS, sfx_volume)
	queue_save()
	changed.emit()

func _apply_audio() -> void:
	_apply_bus(MUSIC_BUS, music_volume)
	_apply_bus(SFX_BUS, sfx_volume)

# the slider scales the bus around its mixed level; 0 mutes it outright
func _apply_bus(bus: StringName, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index == -1 or not _bus_base_db.has(bus):
		push_warning("SaveGame: audio bus '%s' not found" % bus)
		return
	AudioServer.set_bus_mute(index, linear <= 0.0)
	if linear > 0.0:
		AudioServer.set_bus_volume_db(index, _bus_base_db[bus] + linear_to_db(linear))

func _to_strings(ids: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for id in ids:
		result.append(String(id))
	return result
