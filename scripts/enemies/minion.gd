class_name Minion
extends Enemy
## Patroller driven by EnemyData. PATROL between two points → CHASE once the hero is inside the
## view cone and no wall hides them → ATTACK (wind-up with a flash and a sound, then the blow) →
## RECOVER (stands open) → CHASE; the next attack also waits for attack_cooldown.
## Never walks off a ledge: with no floor ahead it stands still.

enum State { PATROL, CHASE, ATTACK, RECOVER, DEAD }

@export var data: EnemyData
## Second patrol point relative to the start position (the first one is the start).
@export var patrol_offset: Vector3 = Vector3(4.0, 0.0, 0.0)  # m
@export var alert_sound: AudioStream
## Played when the wind-up starts.
@export var windup_sound: AudioStream
## A patrol point counts as reached this close to it.
@export var patrol_arrive_distance: float = 0.3  # m
## Patrol turns back after making no headway for this long (a crate or a wall in the way).
@export var stuck_time: float = 1.0  # s
## "No headway" = real speed below this share of the wanted speed.
@export var stuck_speed_ratio: float = 0.3
## Below this speed the idle clip plays instead of walk / run.
@export var idle_speed_threshold: float = 0.05  # m/s

@export_group("Attack clip")
## Share of the attack clip (0–1) at which the swing connects; the clip is sped up or slowed
## so that this moment falls on the end of the wind-up.
@export var attack_clip_hit_point: float = 0.5
@export var attack_clip_min_speed: float = 0.3  # playback speed limits, 1 = normal
@export var attack_clip_max_speed: float = 2.0

var state: State = State.PATROL
var _home: Vector3
var _patrol_index: int = 1
var _timer: Timer
var _stuck_left: float = 0.0
var _cooldown_left: float = 0.0

func _ready() -> void:
	if data == null:
		push_error("Minion %s: no EnemyData, using defaults" % name)
		data = EnemyData.new()
	_build_model()
	health.max_hp = data.max_hp
	health.current = data.max_hp
	view_range = data.sight_radius
	super._ready()
	_home = global_position
	_timer = make_state_timer(_on_timer)
	_change_state(State.PATROL)

func patrol_point(index: int) -> Vector3:
	return _home if index == 0 else _home + patrol_offset

func _build_model() -> void:
	if data.model == null:
		push_error("Minion %s: EnemyData has no model" % name)
		return
	var model: Node3D = data.model.instantiate() as Node3D
	model.name = "Model"
	visual.add_child(model)
	visual.scale = Vector3.ONE * data.model_scale

func _think(delta: float) -> void:
	var hero: Node3D = get_live_hero()
	desired_velocity = Vector3.ZERO
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	match state:
		State.PATROL:
			if can_see_player():
				_change_state(State.CHASE)
				return
			_patrol()
		State.CHASE:
			if hero == null or flat_distance_to(hero.global_position) > data.lose_radius:
				_change_state(State.PATROL)
				return
			_chase(hero, delta)
		State.ATTACK:
			if hero != null:
				face_towards(hero.global_position, delta)
	if not desired_velocity.is_zero_approx() and not has_floor_ahead(desired_velocity):
		desired_velocity = Vector3.ZERO
		if state == State.PATROL:
			_turn_back()
	_check_stuck(delta)
	_play_move_anim()

func _patrol() -> void:
	var to_goal: Vector3 = patrol_point(_patrol_index) - global_position
	to_goal.y = 0.0
	if to_goal.length() < patrol_arrive_distance:
		_turn_back()
	else:
		desired_velocity = to_goal.normalized() * data.walk_speed

# runs at the hero; in reach it stops and attacks as soon as the cooldown allows
func _chase(hero: Node3D, delta: float) -> void:
	if flat_distance_to(hero.global_position) > data.attack_range:
		var to_hero: Vector3 = hero.global_position - global_position
		to_hero.y = 0.0
		desired_velocity = to_hero.normalized() * data.run_speed
		return
	face_towards(hero.global_position, delta)
	if _cooldown_left <= 0.0:
		_change_state(State.ATTACK)

func _change_state(next: State) -> void:
	state = next
	_timer.stop()
	_stuck_left = stuck_time
	stop_telegraph()
	set_state_label(State.keys()[next])
	match next:
		State.CHASE:
			Sfx.play(alert_sound, self)
		State.ATTACK:
			restart_anim(anim_attack, _windup_clip_speed())
			start_telegraph(data.attack_windup)
			Sfx.play(windup_sound, self)
			_timer.start(data.attack_windup)
		State.RECOVER:
			_timer.start(data.attack_recovery)

# the only exits of the timed states: ATTACK ends with the blow, RECOVER ends in CHASE
func _on_timer() -> void:
	match state:
		State.ATTACK:
			_strike()
			_change_state(State.RECOVER)
		State.RECOVER:
			_cooldown_left = data.attack_cooldown
			_change_state(State.CHASE)

func _windup_clip_speed() -> float:
	var length: float = anim_length(anim_attack)
	if length <= 0.0 or data.attack_windup <= 0.0:
		return 1.0
	var speed: float = length * attack_clip_hit_point / data.attack_windup
	return clampf(speed, attack_clip_min_speed, attack_clip_max_speed)

# the blow lands only if the hero is still in reach when the wind-up ends
func _strike() -> void:
	var hero: Node3D = get_live_hero()
	if hero == null:
		return
	if flat_distance_to(hero.global_position) > data.attack_range + data.strike_reach_margin:
		return
	if absf(hero.global_position.y - global_position.y) > data.strike_height:
		return
	hurt_hero(data.attack_damage)

func _turn_back() -> void:
	_patrol_index = 1 - _patrol_index
	_stuck_left = stuck_time

func _check_stuck(delta: float) -> void:
	if state != State.PATROL or desired_velocity.is_zero_approx():
		_stuck_left = stuck_time
		return
	var moved: float = Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if moved > desired_velocity.length() * stuck_speed_ratio:
		_stuck_left = stuck_time
		return
	_stuck_left -= delta
	if _stuck_left <= 0.0:
		_turn_back()

func _play_move_anim() -> void:
	if state == State.ATTACK or state == State.RECOVER:
		return
	if desired_velocity.length() < idle_speed_threshold:
		play_anim(anim_idle)
	elif state == State.CHASE:
		play_anim(anim_run)
	else:
		play_anim(anim_walk)

# a hit from behind is felt even though it was not seen
func _on_damaged() -> void:
	if state == State.PATROL:
		_change_state(State.CHASE)

func _on_died() -> void:
	_change_state(State.DEAD)
