extends Node


class_name game_actor


#REF Vars
@onready var gamescene = $".."


#signals
signal res_changed(res: int, new_amt: int)
signal pop_changed(curr_pop: int, max_pop: int)


# Actor structure and units
var bases := []
var buildings := []
var units := []
var loaded_units := {}
var selected_units = []

var unit_tracking_queue := []

# Actor Resources
@onready var resources = {
"wood": 200,
"stone": 200,
"riches": 200,
"crystals": 200,
"food": 200}
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
		set_resource(r,200)
	
	update_pop()


func load_units():	
	loaded_units["Infantry"] = load("res://Units/Infantry.tscn")
	for b in faction_data.buildings:
		if faction_data.buildings[b].has("unit_list"):
			for un in faction_data.buildings[b]["unit_list"]:
				var _unit = un.replace(" ","_")
				if(FileAccess.file_exists("res://Units/"+_unit+".tscn")):
					loaded_units[un] = load("res://Units/"+_unit+".tscn")
				else:
					loaded_units[un] = load("res://Units/"+"Infantry"+".tscn")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if unit_tracking_queue.size()>0:
		pop_front_unit_tracking_queue()


###GAME FUNCTIONS###
## group to add to a
func place_building(bld):
	if bld.is_valid == false:
		return null
	#Connect signals
	bld.pressed.connect(gamescene.building_pressed)
	
	bld.place()
	#update navigation
	await get_tree().physics_frame
	for g in bld.get_groups():
		gamescene.update_navigation(g)
	
		
	#Place building in lists
	gamescene.world_buildings.push_back(bld)
	buildings.push_back(bld)
	
	#Spend resources
	for res in bld.cost:
		adj_resource(res,bld.cost[res]*-1)
		
	#Place bases in bases list
	if bld.type == "Base":
		bases.push_back(bld)
	
	#Adjust max pop
	adj_max_pop(bld.pop_mod)
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


## Check if game actor can afford unit
func can_afford_unit(unit:String, bldg: String):
	for res in faction_data.buildings[bldg]["unit_list"][unit]["base_cost"]:
		if resources[res] < faction_data.buildings[bldg]["unit_list"][unit]["base_cost"][res] :
			return res
	return true


## Add unit to selected list
func select_unit(unit, clr := true):
	if clr:
		clear_selection()
	selected_units.push_back((unit))
	unit.select()


## Remove unit from list
func deselect_unit(unit):
	selected_units.erase(unit)
	unit.select(false)


## Select a group of iunits
func select_group(_units):
	for u in _units:
		select_unit(u,false)


## Clear unit selected list
func clear_selection():
	for u in selected_units:
		u.select(false)
	selected_units.clear()


## Give a command to all selected units
## iterate var must be at end of arg array
func _group_command(cmnd: Callable, args: Array):
	for j in range(selected_units.size()):
			args[-1] = j	## set iteration
			cmnd.callv(args)


## get position from formation
func formation_pos(unit, place:int):
	return Vector3(fmod(place,5)*unit.unit_radius*2.5,0,int(round(place/5)*unit.unit_radius*2.5))


## Command selected_units to move to location
func command_unit_move(position):
	##Local command function
	var cmnd = func(pos=position, unit:=0):
		var variation = formation_pos(selected_units[unit],unit)
		selected_units[unit].queue_move(pos+variation)
	
	_group_command(cmnd,[position,0])


## Command selected units to attack trgt
func command_unit_attack(trgt):
	##Local command function
	var cmnd = func(target = trgt, unit:=0):
		selected_units[unit].declare_enemy(target)
	
	_group_command(cmnd,[trgt,0])


## Add unit to queue to set move target when tracking
func add_unit_tracking(unit:Unit_Base, track_function: Callable):
	for u in unit_tracking_queue:
		if u[0] == unit:
			u[1] = track_function
			return
	unit_tracking_queue.push_back([unit,track_function])


## Call set target function from tracking queue
func pop_front_unit_tracking_queue():
	var _call = unit_tracking_queue.pop_front()
	if is_instance_valid(_call[0]):
		_call[1].call()


## Remove target unit from unit tracking queue
func erase_from_tracking_queue(unit:Unit_Base):
	for u in unit_tracking_queue:
		if u[0] == unit:
			unit_tracking_queue.erase(u)
