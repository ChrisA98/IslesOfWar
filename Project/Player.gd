extends Node


class_name player


#REF Vars
@onready var gamescene = $".."


#signals
signal res_changed(res: int, new_amt: int)
signal pop_changed(curr_pop: int, max_pop: int)


#Player structure and units
var forts = []
var buildings = []
var units = []

#Player Resources
@onready var resources = {
"wood": 0,
"stone": 0,
"riches": 0,
"crystals": 0,
"food": 0}
var pop: int = 0
var max_pop: int = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	call_deferred("prepare_resources")


#set resources to 0, !!change amt late!!
func prepare_resources():
	await get_tree().physics_frame
	
	#Set resourcest to 0 at start
	for r in resources:
		set_resource(r,0)
	
	update_pop()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


###GAME FUNCTIONS###
#whats on the tin
func place_building(grp):
	var building = gamescene.place_building(grp)
	if building == null:
		return
		
	#Place building in player's list
	buildings.push_back(building)
	
	#Spend resources
	for res in building.cost:
		adj_resource(res,building.cost[res]*-1)
	
	#Hide fort radius
	for i in forts:
			i.hide_radius()
	
	#Place forts in fort list
	if building.type == "Main":
		forts.push_back(building)
	
	#Adjust max pop
	adj_max_pop(building.pop_mod)


##Set resources and population values
func set_resource(resource: String, amt: int):
	resources[resource] = amt
	res_changed.emit(resource, resources[resource])


func adj_resource(resource: String, amt: int):
	resources[resource] += amt
	res_changed.emit(resource, resources[resource])


func set_max_pop(amt: int):
	max_pop = amt
	pop_changed.emit(pop, max_pop)


func adj_max_pop(amt: int):
	max_pop += amt
	pop_changed.emit(pop, max_pop)


func update_pop():
	var pop_cnt = 0
	for i in units:
		pop_cnt += i.unit_cost
	pop = pop_cnt
	pop_changed.emit(pop, max_pop)
