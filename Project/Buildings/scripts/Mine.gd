extends resource_building


var rng = RandomNumberGenerator.new()
var rc: int = 10 #Riches Chance
var riches_amt: int = 5
@export var targ_zone = "Stone_deposit"


# Called when the node enters the scene tree for the first time.
func _ready():
	super()
	rpc = 10
	generate_time = 3
	if(resource == "stone"):
		type = "Mine_stone"
	else:
		type = "Mine_crystal"
		


func set_resource(mode: String):
	resource = mode

func generate_resource():
	super()
	# Generate Riches randomly
	if rng.randi_range(1,100) < rc:
		actor_owner.adj_resource("riches", riches_amt)


func make_valid():
	super()
	for i in $Detection_Area.get_overlapping_areas():
		if i.get_parent().name == targ_zone:
			return
	make_invalid()
