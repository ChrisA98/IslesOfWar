extends resource_building

## amount of each resource to collect from  trade post
var resources = {"wood": 0,
	"stone": 0,
	"riches": 10,
	"crystals": 0,
	"food": 0}

# Called when the node enters the scene tree for the first time.
func _ready():
	super()
	resource = "riches"
	rpc = 10
	generate_time = 3
	type = "Trade_post"


func generate_resource():
	for r in resources:
		actor_owner.adj_resource(r, resources[r])
	timer.start(generate_time)

