extends Label3D

# top_level detaches the tag from the rolling ball's rotation; we copy only its position
@export var follow_offset: Vector3 = Vector3(0, 1.0, 0)

@onready var _target: Node3D = get_parent() as Node3D

func _ready() -> void:
	text = Profile.player_name
	_follow()

func _process(_delta: float) -> void:
	_follow()

func _follow() -> void:
	if _target != null:
		global_position = _target.global_position + follow_offset
