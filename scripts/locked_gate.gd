extends Node3D

@onready var tree: AnimationTree = $AnimationTree

func _ready() -> void:
	add_to_group("locked_gate")

func open() -> void:
	tree.set("parameters/conditions/open", true)
