class_name Enemy
extends CharacterBody3D
## Base of every enemy: group `enemy`, a Health child, weapon hits with a short knockback, gravity,
## the model turning towards its motion, clips played only when the model has them, the shared
## death, the shared sight check (distance → angle → ray against walls), the ledge probe,
## the telegraph flash and the debug state label.
## Subclasses set `desired_velocity` in _think() and react in _on_damaged() / _on_died().

signal died

## Result of look_for_player(), in the order the checks run.
enum Sight { NO_HERO, TOO_FAR, OUT_OF_FOV, BLOCKED, CLEAR }

@export var turn_speed: float = 8.0  # higher = snappier turn, 1/s
@export var knockback_speed: float = 5.0  # m/s
@export var knockback_time: float = 0.2  # s
## Seconds the body stays after death before it is freed; <= 0 keeps it.
@export var free_delay: float = 1.5
## Below this height (fell into a pit) the enemy is removed.
@export var fall_limit_y: float = -20.0  # m
## HP the hero loses by touching this body; 0 = only telegraphed attacks hurt.
@export var contact_damage: int = 1
## Direction the model looks at the start: 0 = +Z (south), 90 = +X (east), 180 = -Z, 270 = -X.
@export var start_yaw_degrees: float = 0.0

@export_group("Senses")
@export var view_range: float = 6.0  # m, on the ground plane
## Full angle of the view cone around the facing direction.
@export var fov_degrees: float = 90.0
@export var eye_height: float = 0.9  # m above the feet, start of the sight ray
@export var target_height: float = 0.7  # m above the hero's feet, end of the sight ray
## A hero this much higher or lower is not seen.
@export var sight_height_limit: float = 3.0  # m
## Layers that block sight and count as floor (walls, floors, props).
@export_flags_3d_physics var world_mask: int = 1
## is_on_screen() is false this close to the screen edge (HUD and touch controls live there).
@export var screen_margin: float = 100.0  # px of the 1920 x 1080 canvas

@export_group("Ledge probe")
@export var ledge_probe_distance: float = 0.5  # m ahead of the body
@export var ledge_probe_lift: float = 0.3  # m above the feet, where the probe ray starts
## A step down deeper than this counts as a pit.
@export var max_step_down: float = 0.6  # m

@export_group("Telegraph")
@export var telegraph_color: Color = Color(1.0, 0.15, 0.1)
## Opacity of the flash at the end of the wind-up, 0–1.
@export var telegraph_peak_alpha: float = 0.7

@export_group("Animations")
## Clip names of the Kenney models; an empty or missing clip is skipped.
@export var anim_idle: StringName = &"idle"
@export var anim_walk: StringName = &"walk"
@export var anim_run: StringName = &"sprint"
@export var anim_attack: StringName = &"attack-melee-right"
@export var anim_die: StringName = &"die"
@export var anim_blend: float = 0.15  # s, cross-fade between clips
@export var anim_restart_blend: float = 0.05  # s, cross-fade into a restarted clip

@export_group("Debug")
## State label and vision drawing; shown in debug builds only.
@export var show_debug: bool = false
@export var debug_label_height: float = 2.2  # m above the feet
@export var debug_label_font_size: int = 96  # px of the Label3D font
@export var debug_line_thickness: float = 0.06  # m, width of the vision lines

@onready var health: Health = $Health
@onready var visual: Node3D = $Visual

## Horizontal velocity the subclass wants this frame.
var desired_velocity: Vector3 = Vector3.ZERO
## The base turns the model towards its motion; a subclass that walks backwards switches it off.
var turn_to_motion: bool = true
## Where the last sight ray hit the world (valid after Sight.BLOCKED).
var sight_block_point: Vector3 = Vector3.ZERO
var _anim: AnimationPlayer
var _dead: bool = false
var _last_hp: int = 0
var _knockback_left: float = 0.0
# found once in _ready
var _hero: Node3D
var _hero_health: Health
var _flash: ModelFlash
var _state_label: Label3D

func _ready() -> void:
	assert(health != null, "Enemy needs a Health child")
	assert(visual != null, "Enemy needs a Visual child")
	add_to_group("enemy")
	visual.rotation.y = deg_to_rad(start_yaw_degrees)
	_find_animation_player()
	_find_hero()
	_setup_debug()
	_last_hp = health.current
	health.changed.connect(_on_health_changed)
	health.died.connect(_die)
	play_anim(anim_idle)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if global_position.y < fall_limit_y:
		queue_free()
		return
	if _dead:
		desired_velocity = Vector3.ZERO
	elif _knockback_left > 0.0:
		_knockback_left -= delta
	else:
		_think(delta)
	if _knockback_left <= 0.0:
		velocity.x = desired_velocity.x
		velocity.z = desired_velocity.z
	move_and_slide()
	if turn_to_motion and not _dead and _knockback_left <= 0.0 and not desired_velocity.is_zero_approx():
		face_direction(desired_velocity, delta)

## Per-frame decision of the subclass: set desired_velocity, turn, change state.
func _think(_delta: float) -> void:
	pass

## Called after a hit that did not kill.
func _on_damaged() -> void:
	pass

## Called once on death, after the base has played the clip and disabled collisions.
func _on_died() -> void:
	pass

func is_dead() -> bool:
	return _dead

## Sword hit: damage plus a short push away from the hero.
func hit_by_weapon(damage: int = 1) -> void:
	if _dead:
		return
	var before: int = health.current
	health.take_damage(damage)
	if health.current >= before or _dead or knockback_speed <= 0.0:
		return
	var hero: Node3D = get_hero()
	var away: Vector3 = global_position - hero.global_position if hero != null else -get_facing()
	away.y = 0.0
	away = -get_facing() if away.is_zero_approx() else away.normalized()
	velocity.x = away.x * knockback_speed
	velocity.z = away.z * knockback_speed
	_knockback_left = knockback_time

## The hero cached in _ready, or null if there is none (or it was freed).
func get_hero() -> Node3D:
	return _hero if is_instance_valid(_hero) else null

## The hero while alive, otherwise null.
func get_live_hero() -> Node3D:
	var hero: Node3D = get_hero()
	if hero == null or _hero_health == null or _hero_health.is_dead():
		return null
	return hero

## Takes `amount` HP from the hero (does nothing without a live hero).
func hurt_hero(amount: int) -> void:
	if get_live_hero() != null:
		_hero_health.take_damage(amount)

func flat_distance_to(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()

func eye_position() -> Vector3:
	return global_position + Vector3.UP * eye_height

## Sight check, cheapest test first: distance, then the view cone, then a ray that only walls,
## floors and props can block.
func look_for_player() -> Sight:
	var hero: Node3D = get_live_hero()
	if hero == null:
		return Sight.NO_HERO
	var to_hero: Vector3 = hero.global_position - global_position
	if flat_distance_to(hero.global_position) > view_range or absf(to_hero.y) > sight_height_limit:
		return Sight.TOO_FAR
	to_hero.y = 0.0
	if get_facing().angle_to(to_hero) > deg_to_rad(fov_degrees * 0.5):
		return Sight.OUT_OF_FOV
	var target: Vector3 = hero.global_position + Vector3.UP * target_height
	var query := PhysicsRayQueryParameters3D.create(eye_position(), target, world_mask)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Sight.CLEAR
	sight_block_point = hit["position"]
	return Sight.BLOCKED

func can_see_player() -> bool:
	return look_for_player() == Sight.CLEAR

## True when the enemy is inside the camera picture (minus screen_margin). Attacks that start
## only while this is true can never come from off-screen. No camera = nobody watches = false.
func is_on_screen() -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(eye_position()):
		return false
	var screen: Rect2 = get_viewport().get_visible_rect().grow(-screen_margin)
	return screen.has_point(camera.unproject_position(eye_position()))

## Probes the floor a little ahead along `direction`; false over a pit or a deep drop.
func has_floor_ahead(direction: Vector3) -> bool:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.is_zero_approx():
		return true
	var from: Vector3 = global_position + flat.normalized() * ledge_probe_distance + Vector3.UP * ledge_probe_lift
	var to: Vector3 = from + Vector3.DOWN * (ledge_probe_lift + max_step_down)
	var query := PhysicsRayQueryParameters3D.create(from, to, world_mask)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## Unit vector the model faces on the ground plane (models look along +Z).
func get_facing() -> Vector3:
	var forward: Vector3 = visual.global_basis.z
	forward.y = 0.0
	return Vector3.BACK if forward.is_zero_approx() else forward.normalized()

func face_direction(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).is_zero_approx():
		return
	var target_yaw: float = atan2(direction.x, direction.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

func face_towards(point: Vector3, delta: float) -> void:
	face_direction(point - global_position, delta)

## Turns to `point` at once (a hit from behind makes the enemy look round).
func face_instantly(point: Vector3) -> void:
	var direction: Vector3 = point - global_position
	if not Vector2(direction.x, direction.z).is_zero_approx():
		visual.rotation.y = atan2(direction.x, direction.z)

## Plays a clip if the model has it and it is not already playing. False if it is missing.
func play_anim(clip: StringName, speed: float = 1.0) -> bool:
	if not has_anim(clip):
		return false
	if _anim.current_animation != clip:
		_anim.play(clip, anim_blend, speed)
	return true

## Starts a clip from its first frame even if it is already playing.
func restart_anim(clip: StringName, speed: float = 1.0) -> bool:
	if not has_anim(clip):
		return false
	_anim.play(clip, anim_restart_blend, speed)
	_anim.seek(0.0, true)
	return true

func has_anim(clip: StringName) -> bool:
	return _anim != null and clip != &"" and _anim.has_animation(clip)

func anim_length(clip: StringName) -> float:
	return _anim.get_animation(clip).length if has_anim(clip) else 0.0

## Wind-up warning: the model fades to telegraph_color over `time` seconds.
func start_telegraph(time: float) -> void:
	if _flash == null:
		_flash = ModelFlash.new()
		add_child(_flash)
		_flash.setup(visual)
	_flash.play(telegraph_color, telegraph_peak_alpha, time)

func stop_telegraph() -> void:
	if _flash != null:
		_flash.stop()

## One-shot Timer child for the timed states of a subclass FSM; it pauses with the game.
func make_state_timer(on_timeout: Callable) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(on_timeout)
	add_child(timer)
	return timer

## Text of the debug label above the head; subclasses call it from their one state-change function.
func set_state_label(text: String) -> void:
	if _state_label != null:
		_state_label.text = text

func _find_animation_player() -> void:
	for node in visual.find_children("*", "AnimationPlayer", true, false):
		_anim = node as AnimationPlayer
		break
	if _anim == null:
		push_warning("Enemy %s: model has no AnimationPlayer" % name)
		return
	# glTF clips import without a loop flag
	for clip in [anim_idle, anim_walk, anim_run]:
		if has_anim(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

func _find_hero() -> void:
	_hero = get_tree().get_first_node_in_group("player") as Node3D
	if _hero == null:
		push_warning("Enemy %s: no Node3D in group \"player\", it will stay passive" % name)
		return
	_hero_health = _hero.get_node_or_null("Health") as Health
	if _hero_health == null:
		push_warning("Enemy %s: the hero has no Health child, it will be ignored" % name)

func _setup_debug() -> void:
	if not show_debug or not OS.is_debug_build():
		return
	_state_label = Label3D.new()
	_state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_state_label.no_depth_test = true
	_state_label.font_size = debug_label_font_size
	_state_label.position = Vector3.UP * debug_label_height
	add_child(_state_label)
	var vision := VisionDebug.new()
	vision.line_thickness = debug_line_thickness
	add_child(vision)

func _on_health_changed(current: int, _max_hp: int) -> void:
	if current < _last_hp and current > 0:
		_on_damaged()
	_last_hp = current

func _die() -> void:
	if _dead:
		return
	_dead = true
	desired_velocity = Vector3.ZERO
	_knockback_left = 0.0
	stop_telegraph()
	# no longer an enemy: the hero's Hurtbox and sword ignore it, it only rests on the floor
	remove_from_group("enemy")
	collision_layer = 0
	restart_anim(anim_die)
	_on_died()
	died.emit()
	if free_delay > 0.0:
		get_tree().create_timer(free_delay, false).timeout.connect(queue_free)
