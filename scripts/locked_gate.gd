extends Node3D

@export_file("*.ogg", "*.wav") var open_sound_path: String = "res://assets/Audio/sfx/gate_open.wav"

@onready var tree: AnimationTree = $AnimationTree

var _open_sound: AudioStream

func _ready() -> void:
	add_to_group("locked_gate")
	_open_sound = Sfx.load_stream(open_sound_path)

func open() -> void:
	tree.set("parameters/conditions/open", true)
	Sfx.play(_open_sound, self)
