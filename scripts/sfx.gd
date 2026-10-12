class_name Sfx
extends RefCounted

# paths already reported missing, so each one warns once per run
static var _missing: Dictionary = {}

## Loads a sound by path; a missing file gives one warning and null (silence), never an error.
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

## Plays a one-shot sound that outlives the caller (hazards free themselves on hit).
## The player sits in the current scene, so it pauses with the game.
static func play(stream: AudioStream, context: Node) -> void:
	if stream == null:
		return
	if context == null or not context.is_inside_tree():
		push_error("Sfx.play: context is not in the tree")
		return
	var tree: SceneTree = context.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.play()
