extends resource_building

# Called when the node enters the scene tree for the first time.
func _ready():
	type = "Lumber_mill"
	super()
	rpc = 10
	generate_time = 3


func make_valid():
	super()
	for i in $Detection_Area.get_overlapping_areas():
		if i.get_parent().name == "Forest":
			return
	make_invalid()
