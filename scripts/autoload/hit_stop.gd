extends Node
## Autoload HitStop: the only script that writes Engine.time_scale. A request slows the game to
## JuiceData.hit_stop_time_scale until one "until" moment measured in real time
## (Time.get_ticks_usec, which time_scale does not touch); overlapping requests keep the later end.
## Time goes back to exactly 1.0 when the stop ends and at once on pause, scene change (restart,
## menu, next level), quit, hero death, the app going to the background or losing focus, and when
## this node leaves the tree. A missed explicit call is still caught on the next frame (paused tree
## or a new current scene), but the explicit calls are what the tests check.

const NORMAL_SCALE: float = 1.0
const USEC_PER_SEC: float = 1000000.0

var _data: JuiceData
## Real-time end of the running stop (usec); 0 = no stop.
var _until_usec: int = 0
## Scene the stop belongs to; a different current scene ends it.
var _scene_id: int = 0
## Scene in which the hero died: no new stop there until the scene changes.
var _blocked_scene_id: int = 0

func _ready() -> void:
	# keeps counting real time while the tree is paused or slowed
	process_mode = Node.PROCESS_MODE_ALWAYS
	_data = JuiceData.get_data()
	GameEventBus.get_bus().hero_died.connect(_on_hero_died)
	# nobody else owns time_scale: start from a known value
	restore()

## Slows time for `duration_sec` real seconds (clamped to hit_stop_max_sec). A stop already running
## ends at the later of the two ends. False when ignored (bad numbers, paused, hero dead here).
func request(duration_sec: float) -> bool:
	if duration_sec <= 0.0 or not _data.hit_stop_ok():
		return false
	var tree: SceneTree = get_tree()
	if tree == null or tree.paused:
		return false
	var scene_id: int = _current_scene_id()
	if scene_id != 0 and scene_id == _blocked_scene_id:
		return false
	var end_usec: int = Time.get_ticks_usec() + int(minf(duration_sec, _data.hit_stop_max_sec) * USEC_PER_SEC)
	_until_usec = maxi(_until_usec, end_usec)
	_scene_id = scene_id
	Engine.time_scale = _data.hit_stop_time_scale
	return true

## Ends any stop now: time_scale is exactly 1.0 afterwards. Safe to call at any time.
func restore() -> void:
	_until_usec = 0
	_scene_id = 0
	Engine.time_scale = NORMAL_SCALE

func is_active() -> bool:
	return _until_usec != 0

## Real seconds left of the running stop (0 when none).
func remaining_sec() -> float:
	if _until_usec == 0:
		return 0.0
	return maxf(float(_until_usec - Time.get_ticks_usec()) / USEC_PER_SEC, 0.0)

func _process(_delta: float) -> void:
	if _until_usec == 0:
		return
	var tree: SceneTree = get_tree()
	if Time.get_ticks_usec() >= _until_usec or tree.paused or _current_scene_id() != _scene_id:
		restore()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, \
		NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			restore()

func _exit_tree() -> void:
	restore()

func _on_hero_died(_position: Vector3) -> void:
	restore()
	_blocked_scene_id = _current_scene_id()

func _current_scene_id() -> int:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return 0
	return tree.current_scene.get_instance_id()
