extends NavigationRegion3D

signal finished_baking

@onready var baking_mesh = false
@onready var global = get_node("/root/Global_Vars")
var baking = false

func _ready():
	bake_finished.connect(open_queue)

func set_nav_region():
	if get_groups().size() == 0:
		print_debug("No Group on Nav_Region")
		return
	navigation_mesh = NavigationMesh.new()
	navigation_mesh.set_parsed_geometry_type(NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS)
	navigation_mesh.set_source_geometry_mode(NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN)
	navigation_mesh.region_min_size = 30
	navigation_mesh.cell_size = .75
	navigation_mesh.set_agent_radius(.75)
	navigation_mesh.set_source_group_name(get_groups()[0])
	

func update_navigation_mesh():
	# use bake and update function of region
	if global.navmesh_baking == null:
		global.set_nav_queue(self)
		var on_thread: bool = true
	
		bake_navigation_mesh(on_thread)
	else:
		global.queued_nav_bakes.push_back(self)


func queue_bake():
	global.set_nav_queue(self)
	var on_thread: bool = true	
	bake_navigation_mesh(on_thread)
	

func open_queue():
	global.clear_nav_queue(self)
	if(global.queued_nav_bakes.size()>0):
		global.queued_nav_bakes[-1].update_navigation_mesh()
