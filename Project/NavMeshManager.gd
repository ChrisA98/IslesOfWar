extends NavigationRegion3D

signal finished_baking

func _ready():
	pass

func set_nav_region(grp):
	navigation_mesh = NavigationMesh.new()
	navigation_mesh.set_parsed_geometry_type(NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS)
	navigation_mesh.set_source_geometry_mode(NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN)
	navigation_mesh.set_source_group_name(grp)
	

func update_navigation_mesh():
	# use bake and update function of region
	var on_thread: bool = true
	bake_navigation_mesh(on_thread)
	finished_baking.emit()
