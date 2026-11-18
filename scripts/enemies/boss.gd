class_name Boss
extends Enemy
## Arena guardian. Stands in the middle and cycles IDLE → TELEGRAPH → ATTACK → REST → IDLE;
## attacks alternate between a fan of fireballs and fire rain around the hero.
## At half HP it enrages: more projectiles, shorter telegraph and rest.
## Every state change goes through _change_state(); every delay is the pausable StateTimer.

signal awakened
signal enraged
## Emitted defeat_delay seconds after death; the level then opens the win screen.
signal defeated

enum State { IDLE, TELEGRAPH, ATTACK, REST, DEAD }
enum Attack { FAN, RAIN }

const DISPLAY_NAME: String = "Страж подземелья"
## ATTACK lasts this long after the last fan volley, so the last balls leave the muzzle first.
const FAN_ATTACK_TAIL: float = 0.3  # s
## Random turn of each rain spot around the ring, so the pattern never repeats exactly.
const RAIN_ANGLE_JITTER: float = 0.3  # rad

@export var fireball_scene: PackedScene
@export var rain_drop_scene: PackedScene

@export_group("Timing")
@export var defeat_delay: float = 2.0

@export_group("Look")
@export var tint: Color = Color(0.55, 0.12, 0.1, 1.0)
@export var aura_color: Color = Color(1.0, 0.2, 0.08, 1.0)
@export var anim_telegraph: StringName = &"crouch"
## Roar on waking up and on every wind-up.
@export var roar_sound: AudioStream
## One whoosh per fan volley and per rain call.
@export var fireball_sound: AudioStream
## Phase 2 starts (played with the «Страж в ярости!» toast).
@export var enraged_sound: AudioStream

@onready var _state_timer: Timer = $StateTimer
@onready var _muzzle: Marker3D = $Visual/Muzzle
@onready var _aura_light: OmniLight3D = $AuraLight
@onready var _aura_ring: MeshInstance3D = $AuraRing
@onready var _telegraph_sfx: AudioStreamPlayer = $TelegraphSfx

## `data` as BossData (set in _apply_data).
var stats: BossData
var state: State = State.IDLE
var _awake: bool = false
var _enraged: bool = false
var _hero_dead: bool = false
var _next_attack: Attack = Attack.FAN
var _hero_start: Vector3 = Vector3.ZERO
var _ring_material: StandardMaterial3D
var _aura_tween: Tween
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	if not is_configured():
		return
	add_to_group("boss")
	_rng.randomize()
	if fireball_scene == null or rain_drop_scene == null:
		push_error("Boss: fireball_scene or rain_drop_scene is not set")
	_tint_model()
	_ring_material = (_aura_ring.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	_aura_ring.material_override = _ring_material
	_telegraph_sfx.stream = roar_sound
	_telegraph_sfx.volume_db = Sfx.volume_db_for(roar_sound)
	_state_timer.one_shot = true
	_state_timer.timeout.connect(_on_state_timeout)
	var hero: Node3D = get_hero()
	if hero != null:
		_hero_start = hero.global_position
		var hero_health: Health = hero.get_node_or_null("Health") as Health
		if hero_health != null:
			hero_health.died.connect(_on_hero_died)
	_set_aura(0.5)
	get_tree().create_timer(stats.wake_delay, false).timeout.connect(awaken)

func is_awake() -> bool:
	return _awake

func is_enraged() -> bool:
	return _enraged

## Projectiles per fan volley in the current phase.
func current_fan_count() -> int:
	return stats.enraged_fan_count if _enraged else stats.fan_count

func current_rain_count() -> int:
	return stats.enraged_rain_count if _enraged else stats.rain_count

## Starts the fight (once).
func awaken() -> void:
	if _awake or _dead or not is_inside_tree():
		return
	_awake = true
	_telegraph_sfx.play()
	awakened.emit()
	_change_state(State.IDLE)

func hit_by_weapon(damage: int = 1) -> void:
	super.hit_by_weapon(damage)
	awaken()

func _think(delta: float) -> void:
	desired_velocity = Vector3.ZERO
	var hero: Node3D = get_live_hero()
	if hero == null:
		return
	if not _awake and hero.global_position.distance_to(_hero_start) > stats.wake_distance:
		awaken()
	if state == State.IDLE or state == State.TELEGRAPH:
		face_towards(hero.global_position, delta)

func _change_state(next: State) -> void:
	state = next
	_state_timer.stop()
	match next:
		State.IDLE:
			play_anim(anim_idle)
			_set_aura(1.0)
			# with the hero dead the boss stays idle: no timer, no more attacks
			if not _hero_dead:
				_state_timer.start(stats.idle_time)
		State.TELEGRAPH:
			restart_anim(anim_telegraph)
			_set_aura(4.0)
			_telegraph_sfx.play()
			_state_timer.start(stats.telegraph_time * _time_scale())
		State.ATTACK:
			restart_anim(anim_attack)
			_set_aura(2.0)
			_state_timer.start(_start_attack())
		State.REST:
			play_anim(anim_idle)
			# dim glow: the window to strike back
			_set_aura(0.2)
			_state_timer.start(stats.rest_time * _time_scale())
		State.DEAD:
			_set_aura(0.0)
			_state_timer.start(defeat_delay)

func _on_state_timeout() -> void:
	match state:
		State.IDLE:
			if not _hero_dead:
				_change_state(State.TELEGRAPH)
		State.TELEGRAPH:
			_change_state(State.ATTACK)
		State.ATTACK:
			_change_state(State.REST)
		State.REST:
			_change_state(State.IDLE)
		State.DEAD:
			defeated.emit()

func _time_scale() -> float:
	return stats.enraged_time_scale if _enraged else 1.0

# fires the next pattern and returns how long the ATTACK state lasts
func _start_attack() -> float:
	var attack: Attack = _next_attack
	_next_attack = Attack.RAIN if attack == Attack.FAN else Attack.FAN
	if attack == Attack.FAN:
		_fire_volleys()
		return stats.volley_gap * stats.fan_volleys + FAN_ATTACK_TAIL
	_call_rain()
	return stats.rain_attack_time

func _fire_volleys() -> void:
	for volley in stats.fan_volleys:
		if state != State.ATTACK or _hero_dead:
			return
		fire_fan()
		if volley < stats.fan_volleys - 1:
			await get_tree().create_timer(stats.volley_gap, false).timeout
			if not is_inside_tree():
				return

## One volley: current_fan_count() fireballs spread evenly, aimed at the hero.
func fire_fan() -> void:
	if fireball_scene == null:
		return
	var hero: Node3D = get_live_hero()
	var aim: Vector3 = (hero.global_position - global_position) if hero != null else get_facing()
	aim.y = 0.0
	aim = aim.normalized() if aim.length_squared() > 0.0001 else get_facing()
	Sfx.play(fireball_sound, self)
	var count: int = current_fan_count()
	var spread: float = stats.enraged_fan_spread_degrees if _enraged else stats.fan_spread_degrees
	for i in count:
		var t: float = float(i) / float(count - 1) if count > 1 else 0.5
		var angle: float = deg_to_rad(lerpf(-spread * 0.5, spread * 0.5, t))
		var ball: Projectile = fireball_scene.instantiate() as Projectile
		if ball == null:
			push_error("Boss: fireball_scene root is not a Projectile")
			return
		ball.speed = stats.fireball_speed
		ball.damage = stats.fireball_damage
		_projectile_parent().add_child(ball)
		ball.launch(_muzzle.global_position, aim.rotated(Vector3.UP, angle))

## current_rain_count() drops: one right under the hero, the rest in a ring around them.
func _call_rain() -> void:
	var hero: Node3D = get_live_hero()
	if hero == null or rain_drop_scene == null:
		return
	Sfx.play(fireball_sound, self)
	var count: int = current_rain_count()
	var base_angle: float = _rng.randf() * TAU
	for i in count:
		var spot: Vector3 = hero.global_position
		if i > 0:
			var angle: float = base_angle + TAU * float(i - 1) / float(count - 1) + _rng.randf_range(-RAIN_ANGLE_JITTER, RAIN_ANGLE_JITTER)
			spot += Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(stats.rain_min_radius, stats.rain_max_radius)
		var ground: Dictionary = _ground_below(spot, hero)
		if ground.is_empty():
			continue  # over a pit: nothing to warn on
		var drop: FireRainDrop = rain_drop_scene.instantiate() as FireRainDrop
		if drop == null:
			push_error("Boss: rain_drop_scene root is not a FireRainDrop")
			return
		_projectile_parent().add_child(drop)
		drop.drop_at(ground["position"])

func _ground_below(spot: Vector3, hero: Node3D) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 3.0, spot + Vector3.DOWN * 4.0)
	query.exclude = [get_rid(), (hero as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func _projectile_parent() -> Node:
	return get_tree().current_scene if get_tree().current_scene != null else get_parent()

func _on_damaged() -> void:
	if not _enraged and health.current <= health.max_hp * stats.enrage_hp_fraction:
		_enraged = true
		Sfx.play(enraged_sound, self)
		enraged.emit()

func _on_died() -> void:
	_change_state(State.DEAD)

func _on_hero_died() -> void:
	_hero_dead = true
	if state != State.DEAD:
		_change_state(State.IDLE)

# dark red copy of every model material (keeps the texture)
func _tint_model() -> void:
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var source: BaseMaterial3D = mesh_instance.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var material: BaseMaterial3D = source.duplicate() as BaseMaterial3D
			material.albedo_color = tint
			material.emission_enabled = true
			material.emission = tint * 0.35
			mesh_instance.set_surface_override_material(surface, material)

# level 0 = off, 1 = calm, 4 = telegraph flare
func _set_aura(level: float) -> void:
	if _aura_tween != null and _aura_tween.is_valid():
		_aura_tween.kill()
	var ring_color := Color(aura_color, clampf(0.15 + level * 0.18, 0.0, 0.9))
	_aura_tween = create_tween().set_parallel(true)
	_aura_tween.tween_property(_aura_light, "light_energy", level * 1.5, 0.2)
	_aura_tween.tween_property(_ring_material, "albedo_color", ring_color, 0.2)
	_aura_tween.tween_property(_aura_ring, "scale", Vector3.ONE * (1.0 + level * 0.06), 0.2)

func _check_data() -> bool:
	if data != null and not data is BossData:
		push_error("%s %s: data must be a BossData, got %s; enemy disabled" % [get_script().get_global_name(), name, data.resource_path])
		return false
	return super()

func _apply_data() -> void:
	stats = data as BossData
	super()
