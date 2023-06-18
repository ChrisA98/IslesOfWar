extends game_actor


@onready var cam = get_node("Player_camera")
@onready var UI_controller = get_node("../UI_Node")

func _ready():
	super()
	res_changed.connect(set_resource)
	pop_changed.connect(set_pop)
	actor_ID = 0


func set_cam_pos(pos: Vector3):
	$RayCast3D.position.x = pos.x
	$RayCast3D.position.z = pos.z
	$RayCast3D.force_raycast_update()
	cam.position = pos


## Set player resource on screen
func set_resource(resource: String, value: int):
	UI_controller.res_displays[resource].clear()
	UI_controller.res_displays[resource].add_text(var_to_str(value))


## Set player population on screen
func set_pop(current: int, _max_pop: int):
	UI_controller.res_displays["pop"].clear()
	UI_controller.res_displays["pop"].push_color(Color.BLACK)
	UI_controller.res_displays["pop"].append_text("[center]")
	UI_controller.res_displays["pop"].append_text("[center]"+var_to_str(current)+" / " + var_to_str(_max_pop)+"[/center]")


func place_building(bld):
	var out = await super(bld) 
	if !out:
		return false
	#Hide base radius
	for i in bases:
			i.hide_radius()
	return out
