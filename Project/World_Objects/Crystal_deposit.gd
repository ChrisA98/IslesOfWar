extends world_object
class_name crystal_deposit

var amount : int = 500:
	set(value):
		amount = value
		$GPUParticles3D.amount = value

func _ready():
	super()
	name = "Crystal_deposit"
	

## Update particle emitter
func _set_shape_radius(value):
	super(value)
	if is_node_ready():
		$GPUParticles3D.process_material.set_shader_parameter("instance_spacing",value)

