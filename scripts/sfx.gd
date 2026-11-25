class_name Sfx
extends RefCounted
## One-shot sound effects. Every effect plays on the SFX bus (music has its own, see MusicPlayer).
## Levels come from AudioMix (resources/audio_mix.tres); the files themselves are not changed.
## The hero's own sounds are 2D (the listener sits on the hero); enemy sounds are 3D (play_3d),
## so a wind-up off-screen is still heard, from its side.

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

## Level for `stream` from the mix (0 dB when not listed or null).
static func volume_db_for(stream: AudioStream) -> float:
	return AudioMix.get_mix().volume_db_for(stream)

## Plays a one-shot sound on the SFX bus that outlives the caller (hazards free themselves on hit).
## Any AudioStream works, an AudioStreamRandomizer too; null is silence.
## The player sits in the current scene, so it pauses with the game unless `always` is set (UI clicks).
static func play(stream: AudioStream, context: Node, always: bool = false) -> void:
	if stream == null:
		return
	var parent: Node = _scene_of(context)
	if parent == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS
	player.volume_db = volume_db_for(stream)
	if always:
		player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.play()

## Plays a positional one-shot at `source`. `follow` = true makes it a child of the source, so it
## moves with it (a wind-up) and stops if the source is freed; false leaves it at the spot in the
## current scene (a death, an explosion). Without a usable 3D mix it falls back to play().
static func play_3d(stream: AudioStream, source: Node3D, follow: bool = true) -> void:
	if stream == null:
		return
	if not AudioMix.get_mix().spatial_ok():
		play(stream, source)
		return
	var parent: Node = source if follow else _scene_of(source)
	if parent == null or not source.is_inside_tree():
		push_error("Sfx.play_3d: source is not in the tree")
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	setup_3d(player)
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	if not follow:
		player.global_position = source.global_position
	player.play()

## Bus, level and falloff for an AudioStreamPlayer3D placed in a scene (e.g. the boss telegraph).
## Call after its stream is set.
static func setup_3d(player: AudioStreamPlayer3D) -> void:
	if player == null:
		push_error("Sfx.setup_3d: player is null")
		return
	var mix: AudioMix = AudioMix.get_mix()
	player.bus = BUS
	player.volume_db = mix.volume_db_for(player.stream)
	if not mix.spatial_ok():
		return  # engine defaults; AudioMix already reported the problem
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = mix.spatial_unit_size
	player.max_distance = mix.spatial_max_distance
	player.max_db = mix.spatial_max_db
	player.attenuation_filter_cutoff_hz = mix.spatial_filter_cutoff_hz

static func _scene_of(context: Node) -> Node:
	if context == null or not context.is_inside_tree():
		push_error("Sfx: context is not in the tree")
		return null
	var tree: SceneTree = context.get_tree()
	return tree.current_scene if tree.current_scene != null else tree.root
