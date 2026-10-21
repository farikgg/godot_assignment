class_name Sfx
extends RefCounted

## Every sound effect plays on this bus (music has its own, see MusicPlayer).
const BUS: StringName = &"SFX"
## Mixing table: volume_db per sound file or randomizer, so recordings made at different levels sit
## together (measured by the loudest 400 ms, aiming at about −14 dBFS; the boss roar a little below
## the hits). Streams not listed play at 0 dB. The files themselves are not changed.
const VOLUME_DB: Dictionary = {
	"res://assets/Audio/hurt.wav": -4.5,
	"res://assets/Audio/death.wav": -3.0,
	"res://assets/Audio/jump.wav": -2.0,
	"res://assets/Audio/coin.wav": 0.0,
	"res://assets/Audio/heal.wav": 5.0,
	"res://assets/Audio/gate_open.wav": 4.0,
	"res://assets/Audio/explosion.wav": 6.0,
	"res://assets/Audio/sword_swing.mp3": 10.0,
	"res://assets/Audio/randomizers/sword_hit.tres": -4.0,
	"res://assets/Audio/randomizers/boss_roar.tres": -2.0,
	"res://assets/Audio/boss_sound/angry.wav": -2.0,
}

# paths already reported missing, so each one warns once per run
static var _missing: Dictionary = {}

## Loads a sound by path. Empty path: silence, no message. Missing file: one warning per path, silence.
static func load_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		if not _missing.has(path):
			_missing[path] = true
			push_warning("Sfx: sound %s not found, staying silent" % path)
		return null
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("Sfx: %s is not an AudioStream" % path)
	return stream

## Level for `stream` from VOLUME_DB (0 dB when not listed or null).
static func volume_db_for(stream: AudioStream) -> float:
	if stream == null:
		return 0.0
	return VOLUME_DB.get(stream.resource_path, 0.0)

## Plays a one-shot sound on the SFX bus that outlives the caller (hazards free themselves on hit).
## Any AudioStream works, an AudioStreamRandomizer too; null is silence.
## The player sits in the current scene, so it pauses with the game unless `always` is set (UI clicks).
static func play(stream: AudioStream, context: Node, always: bool = false) -> void:
	if stream == null:
		return
	if context == null or not context.is_inside_tree():
		push_error("Sfx.play: context is not in the tree")
		return
	var tree: SceneTree = context.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS
	player.volume_db = volume_db_for(stream)
	if always:
		player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.play()
