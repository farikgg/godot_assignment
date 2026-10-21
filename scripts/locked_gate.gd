extends Node3D

@export var open_sound: AudioStream

@onready var tree: AnimationTree = $AnimationTree

func _ready() -> void:
	add_to_group("locked_gate")

func open() -> void:
	tree.set("parameters/conditions/open", true)
	Sfx.play(open_sound, self)
