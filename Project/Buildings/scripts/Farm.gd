extends resource_building


# Called when the node enters the scene tree for the first time.
func _ready():
	super()
	rpc = 10
	generate_time = 3
	type = "Farm"
