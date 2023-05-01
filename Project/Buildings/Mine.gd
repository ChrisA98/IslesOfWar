extends resource_building


var rng = RandomNumberGenerator.new()
var rc: int = 10 #Riches Chance
var riches_amt: int = 5


# Called when the node enters the scene tree for the first time.
func _ready():
	super()
	resource = "stone"
	rpc = 10
	generate_time = 3
	type = "Mine"


func set_resource(mode: String):
	resource = mode

func generate_resource():
	super()
	# Generate Riches randomly
	if rng.randi_range(1,100) < rc:
		actor_owner.adj_resource("riches", riches_amt)
