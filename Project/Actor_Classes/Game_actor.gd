extends Node


class_name game_actor


#REF Vars
@onready var gamescene = $".."


#signals
signal res_changed(res: int, new_amt: int)
signal pop_changed(curr_pop: int, max_pop: int)


# Actor structure and units
var bases = []
var buildings = []
var units = []

# Actor Resources
@onready var resources = {
"wood": 20,
"stone": 20,
"riches": 20,
"crystals": 20,
"food": 20}
var pop: int = 0
var max_pop: int = 0

# Set by gamescene
var actor_ID : int
var faction_data

# Called when the node enters the scene tree for the first time.
func _ready():
	call_deferred("prepare_resources")


#set resources to 0, !!change amt late!!
func prepare_resources():
	await get_tree().physics_frame
	
	#Set resourcest to 0 at start
	for r in resources:
		set_resource(r,20)
	
	update_pop()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


###GAME FUNCTIONS###
## group to add to a
func place_building(grp, bld):
	var building = gamescene.place_building(grp, bld)
	if building == null:
		return false
		
	#Place building in player's list
	buildings.push_back(building)
	
	#Spend resources
	for res in building.cost:
		adj_resource(res,building.cost[res]*-1)
	
	#Hide base radius
	for i in bases:
			i.hide_radius()
	
	#Place bases in bases list
	if building.type == "Base":
		bases.push_back(building)
	
	#Adjust max pop
	adj_max_pop(building.pop_mod)
	buildings.sort()
	return true


##Set resources and population values
func set_resource(resource: String, amt: int):
	resources[resource] = amt
	if(resources[resource] < 0):
		resources[resource] = 0
	res_changed.emit(resource, resources[resource])


func adj_resource(resource: String, amt: int):
	resources[resource] += amt
	if(resources[resource] < 0):
		resources[resource] = 0
	if(resources[resource] > 999):
		resources[resource] = 999
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
		pop_cnt += i.pop_cost
	pop = pop_cnt
	pop_changed.emit(pop, max_pop)


## Checks for building ownership
func owns_building(bldg):
	return buildings.has(bldg)
