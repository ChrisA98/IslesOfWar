extends Building

class_name resource_building 

@export var resource : String = "wood"
var rpc : int = 0 #Resource Per Cycle
var generate_time : int = 10
@onready var timer = get_node("Timer")


# Called when the node enters the scene tree for the first time.
func _ready():
	super()
	timer.timeout.connect(generate_resource)
	$RallyPoint.visible = false #hide rally point
	$StaticBody3D/CollisionShape3D2.disabled = true #hide rally point
	$Detection_Area.set_meta("res_bldg_area",type) #set area meta to building type


func init(pos, snap: int, actor: Node):
	super(pos, snap, actor)


func place():
	super()
	timer.start(generate_time)


func generate_resource():
	actor_owner.adj_resource(resource, rpc)
	timer.start(generate_time)


