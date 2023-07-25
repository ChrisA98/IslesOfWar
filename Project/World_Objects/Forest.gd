extends world_object

@export_range(1,10000000) var random_seed : int = 1

var rng = RandomNumberGenerator.new()
@export var tree_cnt : int = 150

@onready var trees = $Trees_scatter.multimesh


func _ready():
	super()
	position.y = 0
	rng.seed = random_seed
	trees.set_instance_count(0)
	trees.set_use_custom_data(true)
	trees.set_instance_count(tree_cnt)
	call_deferred("_generate_forest")
	
	
func _generate_forest():
	await get_tree().physics_frame
	$Parent_mesh.position.y = get_parent().get_loc_height(position)
	for i in range(trees.get_instance_count()):
		var trans = Transform3D()
		var _scale = rng.randf_range(0.75,1.35)
		trans = trans.scaled(Vector3(_scale,_scale,_scale))
		var alpha = 2 * PI * rng.randf_range(0,360)
		var r = rng.randf_range(-radius,radius)
		var x = r * cos(alpha)
		var z = r * sin(alpha)
		var y = get_parent().get_loc_height(position + Vector3(x,0,z))
		trans = trans.translated(Vector3(x,y,z))
		trees.set_instance_transform(i,trans)

## Add fog overlay from world
func set_fog_overlay(mat):
	$Trees_scatter.set_material_overlay(mat)
