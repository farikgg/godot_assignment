class_name FireRainDrop
extends Projectile
## Fire rain: a red circle with «!» marks the spot for `warning_time`, then the drop falls
## from `fall_height` and hurts the hero within `impact_radius` of the spot. Nothing hurts before that.

@export var warning_time: float = 1.0
@export var fall_height: float = 7.0
@export var impact_radius: float = 1.2
@export var marker_scene: PackedScene = preload("res://scenes/fx/telegraph_marker.tscn")
@export var marker_color: Color = Color(0.9, 0.12, 0.05, 0.5)

var _target: Vector3
var _falling: bool = false
var _marker: TelegraphMarker

func _ready() -> void:
	super._ready()
	# damage comes only from the impact check, never from touching the falling drop
	monitoring = false
	visible = false

func _exit_tree() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()

## Marks `point` (a spot on the floor) and drops on it after warning_time. Call after add_child.
func drop_at(point: Vector3) -> void:
	_target = point
	global_position = point + Vector3.UP * fall_height
	direction = Vector3.DOWN
	_marker = marker_scene.instantiate() as TelegraphMarker
	_marker.radius = impact_radius
	_marker.color = marker_color
	_marker.show_mark = true
	get_parent().add_child(_marker)
	_marker.global_position = point + Vector3.UP * 0.03
	_marker.finished.connect(_start_fall)
	_marker.grow(warning_time)

func is_falling() -> bool:
	return _falling

func _start_fall() -> void:
	_falling = true
	visible = true

func _physics_process(delta: float) -> void:
	if not _falling or _spent:
		return
	global_position += Vector3.DOWN * speed * delta
	if global_position.y <= _target.y:
		global_position.y = _target.y
		_impact()

func _impact() -> void:
	var hero: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if hero != null:
		var offset: Vector3 = hero.global_position - _target
		if Vector2(offset.x, offset.z).length() <= impact_radius and absf(offset.y) < 1.5:
			_hurt(hero)
	_expire()
