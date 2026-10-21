class_name Sfx
extends RefCounted

## Every sound effect plays on this bus (music has its own, see MusicPlayer).
const BUS: StringName = &"SFX"

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

## Plays a one-shot sound on the SFX bus that outlives the caller (hazards free themselves on hit).
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
	if always:
		player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.play()
