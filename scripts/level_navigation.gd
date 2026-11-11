class_name LevelNavigation
extends NavigationRegion3D
## Navigation mesh of a level, baked once when the level loads. Floors (FloorSlab) build their
## collision boxes in _ready, so a mesh saved in the editor could go stale; baking at load always
## matches the real geometry. Source: static colliders of the nodes in the group named in the
## NavigationMesh (`geometry/source_group_name`), on the layers of its collision mask.
## Until the bake is done, and in levels without this node, enemies walk in straight lines.

signal baked

func _ready() -> void:
	if navigation_mesh == null:
		push_warning("LevelNavigation: no NavigationMesh resource, enemies will walk in straight lines")
		return
	bake_finished.connect(_on_bake_finished)
	# one physics frame later every FloorSlab has its shape
	await get_tree().physics_frame
	# on a thread: the level starts without a hitch
	bake_navigation_mesh(true)

func _on_bake_finished() -> void:
	if navigation_mesh.get_polygon_count() == 0:
		push_warning("LevelNavigation: the bake produced no polygons (is the source group empty?)")
	baked.emit()
