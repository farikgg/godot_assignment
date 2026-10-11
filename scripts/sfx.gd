class_name Sfx
extends RefCounted

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
	player.max_polyphony = 1
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.play()
