extends GPUParticles3D
## Fires once and frees itself. Optional flash light fades out with the burst.

@export var flash_light: NodePath
@export var flash_time: float = 0.3

func _ready() -> void:
	one_shot = true
	emitting = true
	finished.connect(queue_free)
	# `finished` never fires without a renderer (headless); free on a pause-aware timer as well
	get_tree().create_timer(lifetime * 2.0 + 0.5, false).timeout.connect(queue_free)
	if not flash_light.is_empty():
		var light: Light3D = get_node_or_null(flash_light) as Light3D
		if light == null:
			push_error("OneShotFx: flash_light %s is not a Light3D" % flash_light)
		else:
			create_tween().tween_property(light, "light_energy", 0.0, flash_time)
