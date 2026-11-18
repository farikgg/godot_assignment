class_name Charger
extends Enemy
## Heavy rusher (zombie). IDLE until the hero is seen while on screen, between stats.min_trigger_distance
## and stats.trigger_range → WINDUP (crouch, red flash,
## sound) → DASH along a straight line fixed when the dash starts → STUNNED (open to hits) → IDLE.
## The dash ends on the hero, at a wall, at a ledge or after stats.dash_distance, and it hurts only a
## hero who is within reach at that moment. Touching the Charger does not hurt.

enum State { IDLE, WINDUP, DASH, STUNNED, DEAD }

@export_group("Look")
@export var windup_sound: AudioStream
@export var anim_windup: StringName = &"crouch"
@export var anim_stunned: StringName = &"emote-no"

## `data` as ChargerData (set in _apply_data).
var stats: ChargerData
var state: State = State.IDLE
var _timer: Timer
# fixed for the whole dash: the Charger does not steer
var _dash_direction: Vector3 = Vector3.BACK

func _ready() -> void:
	super._ready()
	if not is_configured():
		return
	_timer = make_state_timer(_on_timer)
	_change_state(State.IDLE)

func _think(delta: float) -> void:
	desired_velocity = Vector3.ZERO
	var hero: Node3D = get_live_hero()
	match state:
		State.IDLE:
			if not can_see_player():
				return
			# point-blank, or with a pit or a wall right in front, a dash makes no sense: it only watches
			var too_close: bool = flat_distance_to(hero.global_position) < stats.min_trigger_distance
			if too_close or _dash_blocked(_direction_to_hero()):
				face_towards(hero.global_position, delta)
			elif is_on_screen():
				_change_state(State.WINDUP)
		State.WINDUP:
			if hero == null:
				_change_state(State.IDLE)
			else:
				face_towards(hero.global_position, delta)
		State.DASH:
			_dash(hero)

func _dash(hero: Node3D) -> void:
	if _in_reach(hero):
		hurt_hero(stats.dash_damage)
		_change_state(State.STUNNED)
	elif is_on_wall() or not has_floor_ahead(_dash_direction):
		_change_state(State.STUNNED)
	else:
		desired_velocity = _dash_direction * stats.dash_speed

# true when the first step of a dash along `direction` would end at a ledge or against a wall
func _dash_blocked(direction: Vector3) -> bool:
	return not has_floor_ahead(direction) or test_move(global_transform, direction * ledge_probe_distance)

func _can_dash() -> bool:
	return stats.dash_speed > 0.0 and stats.dash_distance > 0.0

func _in_reach(hero: Node3D) -> bool:
	if hero == null:
		return false
	var height_gap: float = absf(hero.global_position.y - global_position.y)
	return flat_distance_to(hero.global_position) <= stats.hit_reach and height_gap <= stats.hit_height

func _change_state(next: State) -> void:
	state = next
	_timer.stop()
	stop_telegraph()
	set_state_label(State.keys()[next])
	match next:
		State.IDLE:
			play_anim(anim_idle)
		State.WINDUP:
			restart_anim(anim_windup)
			start_telegraph(stats.windup_time)
			Sfx.play(windup_sound, self)
			_timer.start(stats.windup_time)
		State.DASH:
			_dash_direction = _direction_to_hero()
			play_anim(anim_run)
			# the timer is the "missed" exit: dash_distance at dash_speed
			_timer.start(stats.dash_distance / stats.dash_speed)
		State.STUNNED:
			restart_anim(anim_stunned)
			_timer.start(stats.stun_time)

# every timed state leaves here
func _on_timer() -> void:
	match state:
		State.WINDUP:
			_change_state(State.DASH if _can_dash() else State.STUNNED)
		State.DASH:
			_change_state(State.STUNNED)
		State.STUNNED:
			_change_state(State.IDLE)

# towards the hero as they stand now; straight ahead if there is no hero
func _direction_to_hero() -> Vector3:
	var hero: Node3D = get_live_hero()
	if hero == null:
		return get_facing()
	var to_hero: Vector3 = hero.global_position - global_position
	to_hero.y = 0.0
	return get_facing() if to_hero.is_zero_approx() else to_hero.normalized()

func _on_damaged() -> void:
	var hero: Node3D = get_live_hero()
	# hit from outside the view cone: look round
	if state == State.IDLE and hero != null:
		face_instantly(hero.global_position)

func _on_died() -> void:
	_change_state(State.DEAD)

func _check_data() -> bool:
	if data != null and not data is ChargerData:
		push_error("%s %s: data must be a ChargerData, got %s; enemy disabled" % [get_script().get_global_name(), name, data.resource_path])
		return false
	return super()

func _apply_data() -> void:
	stats = data as ChargerData
	super()
	view_range = stats.trigger_range
