extends SceneTree
## Frame-time benchmark of one level, for the before/after numbers of each juice stage. Needs a
## window (not --headless). Run from the project folder, e.g. with the phone renderer:
##   Godot --path . --rendering-method mobile --resolution 1920x1080 -s res://tools/measure_fps.gd -- --level=0 --stress
## V-sync off and no FPS cap; the hero stands at its spawn. --stress emits a burst of GameEvents
## (hit, kill, hurt, pickup, landing, win) every STRESS_INTERVAL_SEC at the hero, so effect stages
## are measured with their effects playing. Uses user://measure_fps_save.json (removed at the end).

const SAVE_PATH: String = "user://measure_fps_save.json"
const WARMUP_SEC: float = 3.0
const MEASURE_SEC: float = 10.0
const STRESS_INTERVAL_SEC: float = 0.5
const USEC_PER_SEC: float = 1000000.0
const USEC_PER_MSEC: float = 1000.0
const PERCENTILE_95: float = 0.95
const PERCENTILE_99: float = 0.99
const LEVEL_ARG: String = "--level="
const STRESS_ARG: String = "--stress"

var _save: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_save = root.get_node("SaveGame")
	_save.save_path = SAVE_PATH
	_cleanup()
	var level_index: int = 0
	var stress: bool = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(LEVEL_ARG):
			level_index = arg.trim_prefix(LEVEL_ARG).to_int()
		elif arg == STRESS_ARG:
			stress = true
	# every level open, so any index can be measured
	for id in root.get_node("GameFlow").level_ids():
		_save.record_level_result(id, 0, 0.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if root.get_node("GameFlow").start_level(level_index) != OK:
		printerr("measure_fps: cannot start level %d" % level_index)
		_finish(1)
		return
	await create_timer(WARMUP_SEC, true, false, true).timeout

	var frame_usec: PackedInt64Array = []
	var draw_calls: int = 0
	var objects: int = 0
	var start: int = Time.get_ticks_usec()
	var last: int = start
	var next_stress: int = start
	while last - start < int(MEASURE_SEC * USEC_PER_SEC):
		await process_frame
		var now: int = Time.get_ticks_usec()
		frame_usec.append(now - last)
		last = now
		draw_calls += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		objects += int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		if stress and now >= next_stress:
			next_stress = now + int(STRESS_INTERVAL_SEC * USEC_PER_SEC)
			_emit_burst()

	var count: int = frame_usec.size()
	var total_sec: float = float(last - start) / USEC_PER_SEC
	var sorted: Array = Array(frame_usec)
	sorted.sort()
	print("measure_fps level=%d stress=%s renderer=%s frames=%d" % [level_index, stress,
		RenderingServer.get_current_rendering_method(), count])
	print("  avg FPS %.1f   mean %.2f ms   p95 %.2f ms   p99 %.2f ms   max %.2f ms" % [
		float(count) / total_sec, total_sec * USEC_PER_MSEC / float(count),
		_ms(sorted, PERCENTILE_95), _ms(sorted, PERCENTILE_99), float(sorted[count - 1]) / USEC_PER_MSEC])
	print("  avg draw calls %d   avg objects %d" % [draw_calls / count, objects / count])
	_finish(0)

func _emit_burst() -> void:
	var events: Node = root.get_node("GameEvents")
	var hero: Node3D = get_first_node_in_group("player") as Node3D
	var enemy: Node3D = get_first_node_in_group("enemy") as Node3D
	if hero == null:
		return
	var at: Vector3 = hero.global_position
	if enemy != null:
		events.emit_signal(&"enemy_hit", at, enemy, false)
		events.emit_signal(&"enemy_died", at, enemy)
	events.emit_signal(&"hero_hurt", at, 1)
	events.emit_signal(&"pickup_collected", at, &"coin")
	events.emit_signal(&"hero_landed", at, 6.0)
	events.emit_signal(&"level_won", at)

func _ms(sorted: Array, share: float) -> float:
	var index: int = clampi(int(share * float(sorted.size())), 0, sorted.size() - 1)
	return float(sorted[index]) / USEC_PER_MSEC

func _finish(code: int) -> void:
	root.get_node("MusicPlayer").stop_all()
	root.get_node("GameFlow").stop_all_sounds()
	await create_timer(0.2, true, false, true).timeout
	_cleanup()
	quit(code)

func _cleanup() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
