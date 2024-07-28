extends NavigationRegion3D

signal starting_baking
signal finished_baking
signal queue_cleared

@onready var baking_mesh = false
@onready var global = get_node("/root/Global_Vars")
@export var min_size: float = 60
@export var cell_size: float = .35
@export var cell_height: float = .25
@export var edge_max_length: float = 11.9
@export var agent_max_slope: float = 35
@export var agent_radius: float = 2
@export var connects: bool = true
var baking = false

func _ready():
	bake_finished.connect(open_queue)

func set_nav_region():
	if get_groups().size() == 0:
		print_debug("No Group on Nav_Region")
		return
	navigation_mesh = NavigationMesh.new()
	navigation_mesh.set_parsed_geometry_type(NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS)
	navigation_mesh.set_source_geometry_mode(NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT)
	navigation_mesh.region_min_size = min_size
	navigation_mesh.cell_size = cell_size
	navigation_mesh.set_cell_height(cell_height)
	navigation_mesh.edge_max_length = cell_size*400
	navigation_mesh.agent_max_slope = agent_max_slope
	navigation_mesh.region_merge_size = cell_size*100
	navigation_mesh.set_agent_radius(agent_radius)
	navigation_mesh.set_source_group_name(get_groups()[0])
	

func update_navigation_mesh():
	# use bake and update function of region
	if global.navmesh_baking == null:
		starting_baking.emit()
		global.push_nav_queue(self)
		var on_thread: bool = true	
		bake_navigation_mesh(on_thread)
	else:
		global.queued_nav_bakes.push_back(self)


func queue_bake():
	global.push_nav_queue(self)
	var on_thread: bool = true	
	bake_navigation_mesh(on_thread)


func open_queue():
	finished_baking.emit()
	global.pop_nav_queue(self)
	if(global.queued_nav_bakes.size()>0):
		global.queued_nav_bakes[-1].update_navigation_mesh()
	else:
		queue_cleared.emit()


func _exit_tree():
	global.clear_nav_queue()
	
