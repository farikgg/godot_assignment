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

@export var fireball_scene: PackedScene
@export var rain_drop_scene: PackedScene

@export_group("Timing")
@export var idle_time: float = 1.0
@export var telegraph_time: float = 0.8
@export var rest_time: float = 2.5
@export var defeat_delay: float = 2.0
## Telegraph and rest are multiplied by this in phase 2.
@export var enraged_time_scale: float = 0.7
## The fight starts when the hero walks this far from their start, or after wake_delay seconds.
@export var wake_distance: float = 2.0
@export var wake_delay: float = 2.0

@export_group("Fan")
@export var fan_count: int = 5
@export var fan_spread_degrees: float = 50.0
@export var enraged_fan_count: int = 7
@export var enraged_fan_spread_degrees: float = 80.0
@export var fan_volleys: int = 2
@export var volley_gap: float = 0.45

@export_group("Rain")
@export var rain_count: int = 4
@export var enraged_rain_count: int = 6
## Rain spots lie this far from the hero (the first one is right under them).
@export var rain_min_radius: float = 1.5
@export var rain_max_radius: float = 3.0
## How long the boss stays in ATTACK after calling the rain.
@export var rain_attack_time: float = 1.2

@export_group("Look")
@export var tint: Color = Color(0.55, 0.12, 0.1, 1.0)
@export var aura_color: Color = Color(1.0, 0.2, 0.08, 1.0)
@export var anim_telegraph: StringName = &"crouch"
## Roar on waking up and on every wind-up.
@export_file("*.ogg", "*.wav") var roar_sound_path: String = "res://assets/Audio/sfx/boss_roar.wav"
## One whoosh per fan volley and per rain call.
@export_file("*.ogg", "*.wav") var fireball_sound_path: String = "res://assets/Audio/sfx/fireball.wav"

@onready var _state_timer: Timer = $StateTimer
@onready var _muzzle: Marker3D = $Visual/Muzzle
@onready var _aura_light: OmniLight3D = $AuraLight
@onready var _aura_ring: MeshInstance3D = $AuraRing
@onready var _telegraph_sfx: AudioStreamPlayer = $TelegraphSfx

var state: State = State.IDLE
var _awake: bool = false
var _enraged: bool = false
var _hero_dead: bool = false
var _next_attack: Attack = Attack.FAN
var _hero_start: Vector3 = Vector3.ZERO
var _ring_material: StandardMaterial3D
var _aura_tween: Tween
var _rng := RandomNumberGenerator.new()
var _fireball_sound: AudioStream

func _ready() -> void:
	super._ready()
	add_to_group("boss")
	_rng.randomize()
	if fireball_scene == null or rain_drop_scene == null:
		push_error("Boss: fireball_scene or rain_drop_scene is not set")
	_tint_model()
	_ring_material = (_aura_ring.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	_aura_ring.material_override = _ring_material
	_telegraph_sfx.stream = Sfx.load_stream(roar_sound_path)
	_fireball_sound = Sfx.load_stream(fireball_sound_path)
	_state_timer.one_shot = true
	_state_timer.timeout.connect(_on_state_timeout)
	var hero: Node3D = get_hero()
	if hero != null:
		_hero_start = hero.global_position
		var hero_health: Health = hero.get_node_or_null("Health") as Health
		if hero_health != null:
			hero_health.died.connect(_on_hero_died)
	_set_aura(0.5)
	get_tree().create_timer(wake_delay, false).timeout.connect(awaken)

func is_awake() -> bool:
	return _awake

func is_enraged() -> bool:
	return _enraged

## Projectiles per fan volley in the current phase.
func current_fan_count() -> int:
	return enraged_fan_count if _enraged else fan_count

func current_rain_count() -> int:
	return enraged_rain_count if _enraged else rain_count

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
	if not _awake and hero.global_position.distance_to(_hero_start) > wake_distance:
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
				_state_timer.start(idle_time)
		State.TELEGRAPH:
			restart_anim(anim_telegraph)
			_set_aura(4.0)
			_telegraph_sfx.play()
			_state_timer.start(telegraph_time * _time_scale())
		State.ATTACK:
			restart_anim(anim_attack)
			_set_aura(2.0)
			_state_timer.start(_start_attack())
		State.REST:
			play_anim(anim_idle)
			# dim glow: the window to strike back
			_set_aura(0.2)
			_state_timer.start(rest_time * _time_scale())
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
	return enraged_time_scale if _enraged else 1.0

# fires the next pattern and returns how long the ATTACK state lasts
func _start_attack() -> float:
	var attack: Attack = _next_attack
	_next_attack = Attack.RAIN if attack == Attack.FAN else Attack.FAN
	if attack == Attack.FAN:
		_fire_volleys()
		return volley_gap * fan_volleys + 0.3
	_call_rain()
	return rain_attack_time

func _fire_volleys() -> void:
	for volley in fan_volleys:
		if state != State.ATTACK or _hero_dead:
			return
		fire_fan()
		if volley < fan_volleys - 1:
			await get_tree().create_timer(volley_gap, false).timeout
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
	Sfx.play(_fireball_sound, self)
	var count: int = current_fan_count()
	var spread: float = enraged_fan_spread_degrees if _enraged else fan_spread_degrees
	for i in count:
		var t: float = float(i) / float(count - 1) if count > 1 else 0.5
		var angle: float = deg_to_rad(lerpf(-spread * 0.5, spread * 0.5, t))
		var ball: Projectile = fireball_scene.instantiate() as Projectile
		if ball == null:
			push_error("Boss: fireball_scene root is not a Projectile")
			return
		_projectile_parent().add_child(ball)
		ball.launch(_muzzle.global_position, aim.rotated(Vector3.UP, angle))

## current_rain_count() drops: one right under the hero, the rest in a ring around them.
func _call_rain() -> void:
	var hero: Node3D = get_live_hero()
	if hero == null or rain_drop_scene == null:
		return
	Sfx.play(_fireball_sound, self)
	var count: int = current_rain_count()
	var base_angle: float = _rng.randf() * TAU
	for i in count:
		var spot: Vector3 = hero.global_position
		if i > 0:
			var angle: float = base_angle + TAU * float(i - 1) / float(count - 1) + _rng.randf_range(-0.3, 0.3)
			spot += Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(rain_min_radius, rain_max_radius)
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
	if not _enraged and health.current * 2 <= health.max_hp:
		_enraged = true
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
