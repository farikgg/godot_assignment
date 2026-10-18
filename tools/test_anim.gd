extends SceneTree
## Animation smoke test for map.tscn.
## Run: godot --headless --path . -s tools/test_anim.gd   (exit code 0 = all PASS, 1 = any FAIL)

const MAP_SCENE: String = "res://scenes/map.tscn"
const LOOP_CLIPS: Array[StringName] = [&"spin_bob", &"spin", &"patrol", &"pulse"]
# locked gate open height: iron fence 0.879 m x2 + 0.3 clearance
const GATE_OPEN_Y: float = 2.058
const SAMPLE_GAP: float = 0.5
const POSITION_TOLERANCE: float = 0.01

var _failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", label, ("  (" + detail + ")") if detail != "" else ""])

func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame

func _run() -> void:
	var map: Node3D = (load(MAP_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(map)

	await _test_gate(map)
	await _test_motion(map)
	_test_loops(map)
	_test_callback_modes(map)

	var code: int = 1 if _failures > 0 else 0
	print("RESULT: %s, %d failure(s), exit code %d" % ["PASS" if code == 0 else "FAIL", _failures, code])
	quit(code)

func _test_gate(map: Node3D) -> void:
	var gate: Node = map.get_node_or_null("LockedGate")
	var body: Node3D = map.get_node_or_null("LockedGate/Body") as Node3D
	if gate == null or body == null:
		_check("locked gate: LockedGate/Body found", false)
		return
	await _physics_frames(30)
	var closed_y: float = body.position.y
	_check("locked gate closed after 30 physics frames", absf(closed_y) < POSITION_TOLERANCE, "y=%.3f" % closed_y)
	gate.call("open")
	await _physics_frames(60)
	var open_y: float = body.position.y
	_check("locked gate raised 60 frames after open()", absf(open_y - GATE_OPEN_Y) < POSITION_TOLERANCE, "y=%.3f" % open_y)

func _sample(map: Node3D) -> Dictionary:
	var coin: Node3D = null
	for node in map.get_tree().get_nodes_in_group("coins"):
		coin = node as Node3D
		break
	var coin_model: Node3D = coin.get_node_or_null("Model") as Node3D if coin != null else null
	var key_model: Node3D = map.get_node_or_null("KeyPickup/Model") as Node3D
	var saw: Node3D = map.get_node_or_null("Enemies/Saw/Body/Blade") as Node3D
	var patrol_body: Node3D = map.get_node_or_null("Enemies/SawPatrol/Body") as Node3D
	var patrol_blade: Node3D = map.get_node_or_null("Enemies/SawPatrol/Body/Blade") as Node3D
	var pulse: Node3D = map.get_node_or_null("Exit/PulseZone/Disc") as Node3D
	return {
		"coin": Vector2(coin_model.rotation_degrees.y, coin_model.position.y) if coin_model != null else null,
		"key": Vector2(key_model.rotation_degrees.y, key_model.position.y) if key_model != null else null,
		"saw spin": saw.rotation_degrees.z if saw != null else null,
		"patrol saw spin": patrol_blade.rotation_degrees.z if patrol_blade != null else null,
		"patrol saw move": patrol_body.position.x if patrol_body != null else null,
		"pulse": pulse.scale.x if pulse != null else null,
	}

func _test_motion(map: Node3D) -> void:
	var first: Dictionary = _sample(map)
	await create_timer(SAMPLE_GAP).timeout
	var second: Dictionary = _sample(map)
	for key: String in first:
		var a: Variant = first[key]
		var b: Variant = second[key]
		if a == null or b == null:
			_check("%s animates" % key, false, "node not found")
		else:
			_check("%s animates" % key, a != b, "%s -> %s" % [a, b])

func _all_mixers(map: Node) -> Array[AnimationMixer]:
	var out: Array[AnimationMixer] = []
	for node in map.find_children("*", "AnimationMixer", true, false):
		out.append(node as AnimationMixer)
	return out

func _test_loops(map: Node3D) -> void:
	var found: Dictionary = {}
	for mixer in _all_mixers(map):
		var player: AnimationPlayer = mixer as AnimationPlayer
		if player == null:
			continue
		for clip: StringName in player.get_animation_list():
			if clip in LOOP_CLIPS and not found.has(clip):
				found[clip] = true
				var anim: Animation = player.get_animation(clip)
				_check("%s loop_mode = Linear" % clip, anim.loop_mode == Animation.LOOP_LINEAR, "loop_mode=%d" % anim.loop_mode)
				_check("%s autoplay" % clip, player.autoplay == clip, "autoplay=%s" % player.autoplay)
	for clip in LOOP_CLIPS:
		if not found.has(clip):
			_check("%s present" % clip, false, "clip not found in map")

func _animation_source(mixer: AnimationMixer) -> AnimationPlayer:
	if mixer is AnimationPlayer:
		return mixer as AnimationPlayer
	if mixer is AnimationTree:
		return mixer.get_node_or_null((mixer as AnimationTree).anim_player) as AnimationPlayer
	return null

func _moves_animatable_body(mixer: AnimationMixer) -> bool:
	var source: AnimationPlayer = _animation_source(mixer)
	var root_node: Node = mixer.get_node_or_null(mixer.root_node)
	if source == null or root_node == null:
		return false
	for clip: StringName in source.get_animation_list():
		var anim: Animation = source.get_animation(clip)
		for track in anim.get_track_count():
			var path: NodePath = anim.track_get_path(track)
			var target: Node = root_node.get_node_or_null(NodePath(path.get_concatenated_names()))
			if target is AnimatableBody3D:
				return true
	return false

func _test_callback_modes(map: Node3D) -> void:
	for mixer in _all_mixers(map):
		if _moves_animatable_body(mixer):
			_check("%s callback_mode_process = Physics" % map.get_path_to(mixer),
				mixer.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS,
				"mode=%d" % mixer.callback_mode_process)
