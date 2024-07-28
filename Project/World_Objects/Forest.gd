extends world_object
class_name forest

var rng = RandomNumberGenerator.new()
@export var prev : bool :
	set(_value):
		if trees != null:
			position.y = 0
			rng.seed = random_seed
			trees.set_instance_count(0)
			trees.set_use_custom_data(true)
			trees.set_instance_count(tree_cnt)
			_generate_forest()
@export var preview_forest: bool


@export_range(1,10000000) var random_seed : int = 1:
	set(value):
		random_seed = value
		rng.seed = random_seed
		_generate_forest()
@export var tree_cnt : int = 550:
	set(value):
		tree_cnt = value
		_generate_forest()
@export var max_slope : float = 7.675:
	set(value):
		max_slope = value
		_generate_forest()


@onready var trees = $Trees_scatter.multimesh

var tree_type : String = "Pine"


func _ready():
	super()
	position.y = 0
	name = "Forest"
	if !Engine.is_editor_hint() and !preview_forest:
		trees.set_instance_count(0)
		trees.set_use_custom_data(true)
		call_deferred("_generate_forest")
		return
	prev = true



## Generate forest evenly around radius
func _generate_forest(gen_obstacles: bool = true):
	if !is_node_ready():
		return
	
	trees.set_instance_count(tree_cnt)
	rng.seed = random_seed
	
	local_area.position.y = get_loc_height(global_position)
	global_position.y = 0
	
	for i in range(trees.get_instance_count()):
		var trans = Transform3D()
		var _scale = rng.randf_range(0.75,1.35)
		trans = trans.scaled(Vector3(_scale,_scale,_scale))
		var alpha = 2 * PI * rng.randf_range(0,360)
		var r = rng.randf_range(-radius,radius)
		var x = r * cos(alpha)
		var z = r * sin(alpha)
		var y1 = get_loc_height(global_position + Vector3(x,0,z))
		var y2 = get_loc_height(global_position + Vector3(x+3,0,z))
		var y3 = get_loc_height(global_position + Vector3(x,0,z+3))
		var y4 = get_loc_height(global_position + Vector3(x-3,0,z))
		var y5 = get_loc_height(global_position + Vector3(x,0,z-3))
		
		if (y1 <= Global_Vars.water_elevation):
			trans = trans.translated(Vector3(x,-1000,z))
		elif (abs(y2-y4) >= max_slope/10):
			trans = trans.translated(Vector3(x,-1000,z))
		elif (abs(y3-y5) >= max_slope/10):
			trans = trans.translated(Vector3(x,-1000,z))
		else:
			if gen_obstacles:
				var obstacle = NavigationObstacle3D.new()
				obstacle.radius = 1
				obstacle.position = Vector3(x,y1,z)
				obstacle.use_3d_avoidance = true
				obstacle.set_navigation_map(Global_Vars.nav_map)
				add_child(obstacle)
			trans = trans.translated(Vector3(x,y1,z))
			trees.set_instance_custom_data(i,Color(rng.randf_range(0,360),0,0,0))
		
		trees.set_instance_transform(i,trans)


func _set_shape_radius(value):
	super(value)
	_generate_forest()

## Add fog overlay from world
func set_fog_overlay(mat):
	$Trees_scatter.set_material_overlay(mat)


func update_heightmap():
	super()
	_generate_forest(false)


func set_tree_type(_tree_type):
	$Trees_scatter.multimesh.mesh = find_child(_tree_type).mesh
	tree_type = tree_type


func hide_avoidance_zones_under_buildings(img : Image, offset:int):
	for nod in get_children():
		if nod is NavigationObstacle3D:
			if img.get_pixel(nod.global_position.x+offset,nod.global_position.z+offset).r !=0:
				nod.queue_free()
