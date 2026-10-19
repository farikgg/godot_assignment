class_name CharacterData
extends Resource

@export var id: StringName
@export var display_name: String
@export var model: PackedScene
## Shop price; not used yet.
@export var price: int = 0
@export var unlocked_by_default: bool = true
## Uniform scale of the model inside the player's Visual node.
@export var model_scale: float = 1.4
## Bone the sword attaches to (Kenney mini characters: "arm-right").
@export var hand_bone: StringName = &"arm-right"
## Shoulder-to-fingertip length of the arm in model units (Kenney rig: ~0.28, arm along -X of the bone).
@export var arm_length: float = 0.28

@export_group("Animations")
## Empty string = the character has no such animation; it is skipped.
@export var anim_idle: StringName = &"idle"
@export var anim_run: StringName = &"sprint"
@export var anim_attack: StringName = &"attack-melee-right"
@export var anim_hit: StringName = &""
@export var anim_die: StringName = &"die"
## In the air: rising / falling.
@export var anim_jump: StringName = &"jump"
@export var anim_fall: StringName = &"fall"
