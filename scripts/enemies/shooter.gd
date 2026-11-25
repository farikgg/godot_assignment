class_name Shooter
extends Enemy
## Ranged sentry (skeleton). IDLE until the hero is seen → RETREAT while they are too close →
## AIM (laser, flash and sound for stats.aim_time) → FIRE (one slow bolt along the laser) → COOLDOWN → IDLE.
## It never aims at a hero it cannot see, or while it is itself off-screen. Touching it does not hurt.

enum State { IDLE, RETREAT, AIM, FIRE, COOLDOWN, DEAD }

## Scene whose root is a Projectile.
@export var bolt_scene: PackedScene

@export_group("Look")
@export var aim_sound: AudioStream
@export var shoot_sound: AudioStream
@export var anim_aim: StringName = &"holding-right"
@export var anim_shoot: StringName = &"holding-right-shoot"

@onready var _muzzle: Marker3D = get_node_or_null("Visual/Muzzle") as Marker3D
@onready var _laser: MeshInstance3D = get_node_or_null("Laser") as MeshInstance3D

## `data` as ShooterData (set in _apply_data).
var stats: ShooterData
var state: State = State.IDLE
var _timer: Timer
# where the laser points; the bolt flies along it
var _aim_direction: Vector3 = Vector3.BACK

func _ready() -> void:
	# it backs away while still looking at the hero
	turn_to_motion = false
	super._ready()
	if not is_configured():
		return
	if bolt_scene == null:
		push_warning("Shooter %s: bolt_scene is not set, it will not shoot" % name)
	if _muzzle == null:
		push_warning("Shooter %s: no Visual/Muzzle, shots start at eye height" % name)
	if _laser == null:
		push_warning("Shooter %s: no Laser node, the aim line will not show" % name)
	else:
		# placed in world space every frame of AIM
		_laser.top_level = true
	_timer = make_state_timer(_on_timer)
	_change_state(State.IDLE)

func _think(delta: float) -> void:
	desired_velocity = Vector3.ZERO
	var hero: Node3D = get_live_hero()
	match state:
		State.IDLE:
			if not can_see_player():
				return
			if flat_distance_to(hero.global_position) < stats.retreat_distance:
				_change_state(State.RETREAT)
			elif is_on_screen():
				_change_state(State.AIM)
		State.RETREAT:
			if hero == null:
				_change_state(State.IDLE)
				return
			_retreat_from(hero, delta)
		State.AIM:
			# the hero stepped behind cover or out of range: no blind shot
			if not _can_aim():
				_change_state(State.IDLE)
				return
			face_towards(hero.global_position, delta)
			_aim_at(hero)

func _retreat_from(hero: Node3D, delta: float) -> void:
	face_towards(hero.global_position, delta)
	var away: Vector3 = global_position - hero.global_position
	away.y = 0.0
	away = away.normalized()
	var far_enough: bool = flat_distance_to(hero.global_position) >= stats.keep_distance
	# cornered at a wall or a ledge: stop backing away and shoot instead
	if far_enough or is_on_wall() or not has_floor_ahead(away):
		_end_retreat()
	else:
		desired_velocity = away * stats.retreat_speed

func _end_retreat() -> void:
	_change_state(State.AIM if _can_aim() else State.IDLE)

func _can_aim() -> bool:
	return can_see_player() and is_on_screen()

func _change_state(next: State) -> void:
	state = next
	_timer.stop()
	stop_telegraph()
	_show_laser(false)
	set_state_label(State.keys()[next])
	match next:
		State.IDLE:
			play_anim(anim_idle)
		State.RETREAT:
			play_anim(anim_walk)
			_timer.start(stats.retreat_max_time)
		State.AIM:
			play_anim(anim_aim)
			start_telegraph(stats.aim_time)
			Sfx.play_3d(aim_sound, self)
			_timer.start(stats.aim_time)
		State.FIRE:
			restart_anim(anim_shoot)
			_fire()
			_timer.start(stats.fire_time)
		State.COOLDOWN:
			play_anim(anim_idle)
			_timer.start(stats.cooldown_time)

# every timed state leaves here
func _on_timer() -> void:
	match state:
		State.RETREAT:
			_end_retreat()
		State.AIM:
			_change_state(State.FIRE)
		State.FIRE:
			_change_state(State.COOLDOWN)
		State.COOLDOWN:
			_change_state(State.IDLE)

func _muzzle_position() -> Vector3:
	return _muzzle.global_position if _muzzle != null else eye_position()

# the laser runs level from the muzzle to the hero: exactly the path the bolt will take
func _aim_at(hero: Node3D) -> void:
	var from: Vector3 = _muzzle_position()
	var to := Vector3(hero.global_position.x, from.y, hero.global_position.z)
	if from.is_equal_approx(to):
		return
	_aim_direction = from.direction_to(to)
	if _laser == null:
		return
	# the mesh is 1 m long along Z: turn it along the aim and stretch it to the hero
	var aim_basis: Basis = Basis.looking_at(_aim_direction).scaled_local(Vector3(1.0, 1.0, from.distance_to(to)))
	_laser.global_transform = Transform3D(aim_basis, (from + to) * 0.5)
	_show_laser(true)

func _show_laser(shown: bool) -> void:
	if _laser != null:
		_laser.visible = shown

func _fire() -> void:
	if bolt_scene == null:
		return
	var node: Node = bolt_scene.instantiate()
	var bolt: Projectile = node as Projectile
	if bolt == null:
		push_warning("Shooter %s: bolt_scene root is not a Projectile" % name)
		node.free()
		return
	bolt.speed = stats.bolt_speed
	bolt.damage = stats.bolt_damage
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	parent.add_child(bolt)
	bolt.launch(_muzzle_position(), _aim_direction)
	Sfx.play_3d(shoot_sound, self)

func _on_damaged() -> void:
	var hero: Node3D = get_live_hero()
	match state:
		State.IDLE:
			# hit from outside the view cone: look round
			if hero != null:
				face_instantly(hero.global_position)
		State.AIM:
			# a hit breaks the aim
			_change_state(State.COOLDOWN)

func _on_died() -> void:
	_change_state(State.DEAD)

func _check_data() -> bool:
	if data != null and not data is ShooterData:
		push_error("%s %s: data must be a ShooterData, got %s; enemy disabled" % [get_script().get_global_name(), name, data.resource_path])
		return false
	return super()

func _apply_data() -> void:
	stats = data as ShooterData
	super()
	view_range = stats.fire_range
