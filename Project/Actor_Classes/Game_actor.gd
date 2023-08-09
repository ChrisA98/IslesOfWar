extends Node
class_name game_actor



''' Signals '''
signal res_changed(res: int, new_amt: int)
signal pop_changed(curr_pop: int, max_pop: int)
signal building_added(building_pos: Vector3)

'''Actor structure and units'''
var bases := []
var buildings := []
var units := []
var loaded_units := {}
var unit_model_master := {}
var selected_units = []

var unit_tracking_queue := []

'''Identifying Data'''
var actor_ID : int
var faction_data

''' onready vars '''
@onready var gamescene = $".."
# Actor Resources
@onready var resources = {
"wood": 200,
"stone": 200,
"riches": 200,
"crystals": 200,
"food": 200}
@onready var pop: int = 0
@onready var max_pop: int = 0

'''### BUILT-IN METHODS ###'''
# Called when the node enters the scene tree for the first time.
func _ready():
	call_deferred("prepare_resources")

	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if unit_tracking_queue.size()>0:
		pop_front_unit_tracking_queue()


'''### PUBLIC METHODS ###'''
'''-------------------------------------------------------------------------------------'''
'''-------------------------------------------------------------------------------------'''
'''Prepare Start'''

func load_units():
	for un in faction_data["unit_list"]:
		var _unit = un.replace(" ","_").to_lower()		
		if(FileAccess.file_exists("res://Units/"+_unit+".tscn")):
			loaded_units[un] = load("res://Units/"+_unit+".tscn")
		else:
			loaded_units[un] = load("res://Units/"+"infantry"+".tscn")
		unit_model_master[un] = []
		for mod in faction_data["unit_list"][un]["models"]:
			##Load model master
			var model
			if(FileAccess.file_exists("res://Models/Unit/modified_scenes/"+mod+"_va.tscn")):
				model = load("res://Models/Units/modified_scenes/"+mod+"_va.tscn").instantiate()
			else:
				@warning_ignore("assert_always_false")
				model = load("res://Models/Units/modified_scenes/knight_base_va.tscn").instantiate()
			model.name = mod+"_models_master"
			add_child(model)
			unit_model_master[un].push_back(model)

'''Prepare End'''
'''-------------------------------------------------------------------------------------'''
''' Resource Management Start '''
## Set initial resource values to UI
func prepare_resources():
	await get_tree().physics_frame	
	update_pop()


## Set resources and population values
func set_resource(resource: String, amt: int):
	resources[resource] = amt
	if(resources[resource] < 0):
		resources[resource] = 0
	res_changed.emit(resource, resources[resource])


## Adjust resources and population values
func adj_resource(resource: String, amt: int):
	resources[resource] += amt
	if(resources[resource] < 0):
		resources[resource] = 0
	if(resources[resource] > 999):
		resources[resource] = 999
	res_changed.emit(resource, resources[resource])


## Set max population value
func set_max_pop(amt: int):
	max_pop = amt
	pop_changed.emit(pop, max_pop)


## Adjust max population value
func adj_max_pop(amt: int):
	max_pop += amt
	pop_changed.emit(pop, max_pop)


## Calculate current pop
func update_pop():
	var pop_cnt = 0
	for i in units:
		pop_cnt += i.pop_cost
	pop = pop_cnt
	pop_changed.emit(pop, max_pop)

'''Resource Management End'''
'''-------------------------------------------------------------------------------------'''
''' Building Management Start '''

## Place the building in the world
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
	
	building_added.emit(bld.position)
	return true


## Checks for building ownership
func owns_building(bldg):
	return buildings.has(bldg)


'''Building Management End'''
'''-------------------------------------------------------------------------------------'''
''' Unit Training Start '''

## Perfrom standard spawning functions
func spawn_unit(unit_name:String) -> Unit_Base:
	var unit = loaded_units[unit_name].instantiate()
	unit.actor_owner = self
	gamescene.spawn_unit(unit)
	units.push_back(unit)
	update_pop()
	unit.load_data(faction_data["unit_list"][unit_name],unit_model_master[unit_name],0)
	
	return unit


## Check if game actor can afford unit
func can_afford_unit(unit:String):
	for res in faction_data["unit_list"][unit]["base_cost"]:
		if resources[res] < faction_data["unit_list"][unit]["base_cost"][res] :
			return res
	return true


'''Unit Training End'''
'''-------------------------------------------------------------------------------------'''
''' Unit Selection Start '''


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


'''Unit Selection End'''
'''-------------------------------------------------------------------------------------'''
''' Unit Commanding Start '''

## get position from formation
func formation_pos(unit, place:int):
	@warning_ignore("integer_division")
	return Vector3(fmod(place,7)*unit.unit_radius*2.5,0,int(round(place/7)*unit.unit_radius*2.5))


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

'''Unit Commanding End'''
'''-------------------------------------------------------------------------------------'''
''' Unit Tracking Queue Start '''

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

''' Unit Tracking Queue End '''

'''### PRIVATE METHODS ###'''
'''-------------------------------------------------------------------------------------'''
'''-------------------------------------------------------------------------------------'''
''' Unit Commanding Start '''

## Give a command to all selected units
## iterate var must be at end of arg array
func _group_command(cmnd: Callable, args: Array):
	for j in range(selected_units.size()):
			args[-1] = j	## set iteration
			cmnd.callv(args)


''' Unit Commanding End '''
