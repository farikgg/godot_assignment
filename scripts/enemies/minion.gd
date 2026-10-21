class_name Minion
extends Enemy
## Rank-and-file enemy driven by EnemyData. PATROL between two points → CHASE once the hero is
## within sight_radius and in plain view → ATTACK in attack_range (wind-up, blow, cooldown) →
## back to PATROL beyond lose_radius. Never walks off a ledge: with no floor ahead it stands still.

enum State { PATROL, CHASE, ATTACK, DEAD }

@export var data: EnemyData
## Second patrol point relative to the start position (the first one is the start).
@export var patrol_offset: Vector3 = Vector3(4.0, 0.0, 0.0)
@export_file("*.ogg", "*.wav") var alert_sound_path: String = "res://assets/Audio/sfx/orc_alert.wav"
## How far ahead the ledge probe looks, and how deep a step down still counts as floor.
@export var ledge_probe_distance: float = 0.5
@export var max_step_down: float = 0.6
## Patrol turns back after making no headway for this long (a crate or a wall in the way).
@export var stuck_time: float = 1.0

var state: State = State.PATROL
var _home: Vector3
var _patrol_index: int = 1
var _timer: Timer
var _struck: bool = false
var _stuck_left: float = 0.0
var _alert: AudioStream

func _ready() -> void:
	if data == null:
		push_error("Minion %s: no EnemyData, using defaults" % name)
		data = EnemyData.new()
	_build_model()
	health.max_hp = data.max_hp
	health.current = data.max_hp
	super._ready()
	_home = global_position
	_alert = Sfx.load_stream(alert_sound_path)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer)
	add_child(_timer)
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
	match state:
		State.PATROL:
			if hero != null and can_see(hero):
				_change_state(State.CHASE)
				return
			var to_goal: Vector3 = patrol_point(_patrol_index) - global_position
			to_goal.y = 0.0
			if to_goal.length() < 0.3:
				_turn_back()
			else:
				desired_velocity = to_goal.normalized() * data.walk_speed
		State.CHASE:
			if hero == null or flat_distance_to(hero.global_position) > data.lose_radius:
				_change_state(State.PATROL)
				return
			if flat_distance_to(hero.global_position) <= data.attack_range:
				_change_state(State.ATTACK)
				return
			var to_hero: Vector3 = hero.global_position - global_position
			to_hero.y = 0.0
			desired_velocity = to_hero.normalized() * data.run_speed
		State.ATTACK:
			if hero != null:
				face_towards(hero.global_position, delta)
	if desired_velocity != Vector3.ZERO and not has_floor_ahead(desired_velocity):
		desired_velocity = Vector3.ZERO
		if state == State.PATROL:
			_turn_back()
	_check_stuck(delta)
	_play_move_anim()

func _change_state(next: State) -> void:
	state = next
	_timer.stop()
	_stuck_left = stuck_time
	match next:
		State.CHASE:
			Sfx.play(_alert, self)
		State.ATTACK:
			_struck = false
			# slow or speed the clip so its swing lands at the end of the wind-up
			var length: float = anim_length(anim_attack)
			var speed: float = clampf(length * 0.5 / maxf(data.attack_windup, 0.05), 0.3, 2.0) if length > 0.0 else 1.0
			restart_anim(anim_attack, speed)
			_timer.start(data.attack_windup)

func _on_timer() -> void:
	if state != State.ATTACK:
		return
	if not _struck:
		_struck = true
		_strike()
		_timer.start(data.attack_cooldown)
	else:
		_change_state(State.CHASE)

# the blow lands only if the hero is still in reach when the wind-up ends
func _strike() -> void:
	var hero: Node3D = get_live_hero()
	if hero == null:
		return
	if flat_distance_to(hero.global_position) > data.attack_range + 0.4:
		return
	if absf(hero.global_position.y - global_position.y) > 1.2:
		return
	var hero_health: Health = hero.get_node_or_null("Health") as Health
	if hero_health != null:
		hero_health.take_damage(data.attack_damage)

## True when the hero is within sight_radius and nothing solid stands between the eyes and them.
func can_see(hero: Node3D) -> bool:
	if flat_distance_to(hero.global_position) > data.sight_radius:
		return false
	if absf(hero.global_position.y - global_position.y) > 3.0:
		return false
	var eyes: Vector3 = global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(eyes, hero.global_position + Vector3.UP * 0.7)
	query.exclude = [get_rid(), (hero as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## Probes the floor a little ahead along `direction`; false over a pit or a deep drop.
func has_floor_ahead(direction: Vector3) -> bool:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		return true
	var from: Vector3 = global_position + flat.normalized() * ledge_probe_distance + Vector3.UP * 0.3
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (0.3 + max_step_down))
	var exclude: Array[RID] = [get_rid()]
	var hero: Node3D = get_hero()
	if hero != null:
		exclude.append((hero as CollisionObject3D).get_rid())
	query.exclude = exclude
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _turn_back() -> void:
	_patrol_index = 1 - _patrol_index
	_stuck_left = stuck_time

func _check_stuck(delta: float) -> void:
	if state != State.PATROL or desired_velocity == Vector3.ZERO:
		_stuck_left = stuck_time
		return
	var moved: float = Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if moved > desired_velocity.length() * 0.3:
		_stuck_left = stuck_time
		return
	_stuck_left -= delta
	if _stuck_left <= 0.0:
		_turn_back()

func _play_move_anim() -> void:
	if state == State.ATTACK:
		return
	if desired_velocity.length() < 0.05:
		play_anim(anim_idle)
	elif state == State.CHASE:
		play_anim(anim_run)
	else:
		play_anim(anim_walk)

func _on_died() -> void:
	_change_state(State.DEAD)
