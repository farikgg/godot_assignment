class_name Charger
extends Enemy
## Heavy rusher (zombie). IDLE until the hero is seen while on screen, between min_trigger_distance
## and trigger_range → WINDUP (crouch, red flash,
## sound) → DASH along a straight line fixed when the dash starts → STUNNED (open to hits) → IDLE.
## The dash ends on the hero, at a wall, at a ledge or after dash_distance, and it hurts only a
## hero who is within reach at that moment. Touching the Charger does not hurt.

enum State { IDLE, WINDUP, DASH, STUNNED, DEAD }

## The wind-up starts when the hero is seen this close…
@export var trigger_range: float = 6.0  # m
## …but not closer than this: point-blank it only turns to the hero and waits.
@export var min_trigger_distance: float = 2.0  # m

@export_group("Timing")
@export var windup_time: float = 0.7  # s
## Stands dazed after every dash.
@export var stun_time: float = 1.0  # s

@export_group("Dash")
@export var dash_speed: float = 9.0  # m/s
## Longest dash; a miss ends here.
@export var dash_distance: float = 7.0  # m
@export var dash_damage: int = 1  # HP
## The dash hits a hero whose centre is this close on the ground plane…
@export var hit_reach: float = 0.9  # m
## …and not more than this higher or lower (a jump over the Charger is a dodge).
@export var hit_height: float = 1.2  # m

@export_group("Look")
@export var windup_sound: AudioStream
@export var anim_windup: StringName = &"crouch"
@export var anim_stunned: StringName = &"emote-no"

var state: State = State.IDLE
var _timer: Timer
# fixed for the whole dash: the Charger does not steer
var _dash_direction: Vector3 = Vector3.BACK

func _ready() -> void:
	view_range = trigger_range
	super._ready()
	if not _can_dash():
		push_warning("Charger %s: dash_speed and dash_distance must be above 0, it will not dash" % name)
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
			var too_close: bool = flat_distance_to(hero.global_position) < min_trigger_distance
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
		hurt_hero(dash_damage)
		_change_state(State.STUNNED)
	elif is_on_wall() or not has_floor_ahead(_dash_direction):
		_change_state(State.STUNNED)
	else:
		desired_velocity = _dash_direction * dash_speed

# true when the first step of a dash along `direction` would end at a ledge or against a wall
func _dash_blocked(direction: Vector3) -> bool:
	return not has_floor_ahead(direction) or test_move(global_transform, direction * ledge_probe_distance)

func _can_dash() -> bool:
	return dash_speed > 0.0 and dash_distance > 0.0

func _in_reach(hero: Node3D) -> bool:
	if hero == null:
		return false
	var height_gap: float = absf(hero.global_position.y - global_position.y)
	return flat_distance_to(hero.global_position) <= hit_reach and height_gap <= hit_height

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
			start_telegraph(windup_time)
			Sfx.play(windup_sound, self)
			_timer.start(windup_time)
		State.DASH:
			_dash_direction = _direction_to_hero()
			play_anim(anim_run)
			# the timer is the "missed" exit: dash_distance at dash_speed
			_timer.start(dash_distance / dash_speed)
		State.STUNNED:
			restart_anim(anim_stunned)
			_timer.start(stun_time)

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
