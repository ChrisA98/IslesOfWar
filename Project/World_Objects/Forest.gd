@tool
extends world_object

var rng = RandomNumberGenerator.new()
@export var prev : bool :
	set(_value):
		if trees != null:
			position.y = 0
			rng.seed = random_seed
			trees.set_instance_count(0)
			trees.set_use_custom_data(true)
			trees.set_instance_count(tree_cnt)
			_generate_trees_debug()
@export var preview_forest: bool


@export_range(1,10000000) var random_seed : int = 1:
	set(value):
		random_seed = value
		_generate_forest()
@export var tree_cnt : int = 150:
	set(value):
		tree_cnt = value
		_generate_forest()
@export var max_slope : float = .195:
	set(value):
		max_slope = value
		_generate_forest()


@onready var trees = $Trees_scatter.multimesh


func _ready():
	super()
	position.y = 0
	rng.seed = random_seed
	if !Engine.is_editor_hint() and !preview_forest:
		call_deferred("_generate_forest")
		return
	prev = true



## Generate forest evenly around radius
func _generate_forest():
	if !is_node_ready():
		return
	trees.set_instance_count(0)
	trees.set_use_custom_data(true)
	trees.set_instance_count(tree_cnt)
	
	await get_tree().physics_frame
	
	$Parent_mesh.position.y = get_loc_height(position)
	for i in range(trees.get_instance_count()):
		var trans = Transform3D()
		var _scale = rng.randf_range(0.75,1.35)
		trans = trans.scaled(Vector3(_scale,_scale,_scale))
		var alpha = 2 * PI * rng.randf_range(0,360)
		var r = rng.randf_range(-radius,radius)
		var x = r * cos(alpha)
		var z = r * sin(alpha)
		var y1 = get_loc_height(position + Vector3(x,0,z))
		var y2 = get_loc_height(position + Vector3(x+1,0,z))
		var y3 = get_loc_height(position + Vector3(x,0,z+1))
		
		if (abs(y2-y1) > max_slope):
			trans = trans.translated(Vector3(x,-1000,z))
		elif (abs(y3-y1) > max_slope):
			trans = trans.translated(Vector3(x,-1000,z))
		else:
			trans = trans.translated(Vector3(x,y1,z))
		trees.set_instance_transform(i,trans)


## Add fog overlay from world
func set_fog_overlay(mat):
	$Trees_scatter.set_material_overlay(mat)


func _generate_trees_debug():
	$Parent_mesh.position.y = get_loc_height(position)
	for i in range(trees.get_instance_count()):
		var trans = Transform3D()
		var _scale = rng.randf_range(0.75,1.35)
		trans = trans.scaled(Vector3(_scale,_scale,_scale))
		var alpha = 2 * PI * rng.randf_range(0,360)
		var r = rng.randf_range(-radius,radius)
		var x = r * cos(alpha)
		var z = r * sin(alpha)
		var y1 = get_loc_height(position + Vector3(x,0,z))
		var y2 = get_loc_height(position + Vector3(x+1,0,z))
		var y3 = get_loc_height(position + Vector3(x,0,z+1))
		
		if (abs(y2-y1) > max_slope):
			trans = trans.translated(Vector3(x,-1000,z))
		elif (abs(y3-y1) > max_slope):
			trans = trans.translated(Vector3(x,-1000,z))
		else:
			trans = trans.translated(Vector3(x,y1,z))
		trees.set_instance_transform(i,trans)


