extends game_actor

class_name enemy_controller

'''Constant vars'''
const resource_appropriate_nodes = {"Lumber_mill" : "Forest",
"Mine_stone" : "Stone_deposit",
"Mine_crystal" : "Crystal_deposit"}

'''Knowledgebase'''
var resource_locations := {}
var enemy_locations := {}

'''Resource/Pop vars'''
## Resource Per Day
var rpd := {
"wood": 0,
"stone": 0,
"riches": 0,
"crystals": 0,
"food": 0}
## Resource Per Day goal
var rpd_goal := {
"wood": 0,
"stone": 0,
"riches": 0,
"crystals": 0,
"food": 0}
var exp_pop := 1 #expected population after training current users
var selected_units = []
var searching_units = {}

'''Building vars'''
var prepared_building : Building
var picker : RayCast3D	#Raycast for checking locations

'''Goal processing variables'''
var current_goal : String
var goal_queue := []
var deferred_goals := []
var target_item 
var focused_enemy #Current enemy actor targeted

'''Personality vars'''
var think_timer : Timer
var troop_train_patience = .1
var build_patience = .1
var res_search_patience = 5
var enemy_search_patience = 5
var speed_of_thought = 1
var few_troops_threshold = 2
var min_troop_attack = 10
var goal_hierarchy = [
	"attack",
	"expand",
	"explore"
]

''' onready vars '''
@onready var rng = RandomNumberGenerator.new()
@onready var global = get_node("/root/Global_Vars")

'''### BUILT-IN METHODS ###'''
## Called when the node enters the scene tree for the first time.
func _ready():
	add_child(RayCast3D.new())
	picker = get_child(0)
	picker.position.y = 100
	picker.target_position.y = -200
	
	current_goal = "ponder"
	
	## Get taget enemy
	focused_enemy = self	#kick off loop
	think_timer = Timer.new()
	add_child(think_timer)
	think_timer.timeout.connect(think_caller)
	think_timer.start(4)
	
	## -- set resource location categories -- ##
	resource_locations["Lumber_mill"] = []
	resource_locations["Mine_stone"] = []
	resource_locations["Mine_crystal"] = []

'''### Private METHODS ###'''

## build list of enemeis and declare focused enemy
func build_enemy_list():
	for ac in gamescene.game_actors:
		if(ac != self):
			enemy_locations[ac] = []
	while focused_enemy == self:
		focused_enemy = gamescene.game_actors\
		[rng.randi_range(0,gamescene.game_actors.size()-1)]

''' Decision Making start '''
## Make a deferred cal to _think goal
func think_caller():
	call_deferred("_think")


## Decides how to accomplish a goal
func _think():
	think_timer.stop()
	match current_goal:
		"get units":
			__get_units()
		"build":
			__build()
		"uncover_loc":
			__uncover_loc()
		"find":
			__find()
		"attack":
			__attack()
		_:
			ponder()
	think_timer.start(speed_of_thought)


## Consider next plan after goals queue finished
##
## Return false if think not called
func ponder():
	if(goal_queue.size() > 100):
		goal_queue = [["do_nothing","nothing"]]
		breakpoint
		print_debug("goal overflow error")
	
	## Calculate resource rate
	calc_res_rate()
	
	## Get resource building if no income of that source exists
	for res in rpd:
		if rpd[res] == 0:
			decide_resource_goal(res)
	
	## Ensure minimum units are met
	if pop+exp_pop < few_troops_threshold:
		if _attempt_add("get units","something"): #add unit build decision code here
			return true
	
	for goal in goal_hierarchy:
		match goal:
			"attack":
				## Check if they have enough units
				if(pop < min_troop_attack):
					if(pop+exp_pop < min_troop_attack):
						if _attempt_add("get units","something"): #add unit build decision code here
							return true
				else:
					_attempt_add("attack",focused_enemy)
					return true
			_:
				pass
	return false

''' Decision Making end '''
'''-------------------------------------------------------------------------------------'''
''' _think functions start '''

func __get_units():
	if check_for_buildings("Barracks") == false:
		_attempt_add("build","Barracks")
		return
	var barr = get_target_buildings("Barracks")
	var trgt = barr[rng.randi_range(0,barr.size()-1)]
	var u_res = can_afford(faction_data["buildings"]["Barracks"]["unit_list"]["Infantry"]["base_cost"])
	if u_res == null:
		if trgt.push_train_queue("Infantry") == "true":
			exp_pop += faction_data["buildings"]["Barracks"]["unit_list"]["Infantry"]["pop_cost"]
			complete_goal()
		else:
			_attempt_add("build","Barracks")
			return
	else:
		var ttt = troop_train_patience_decide(u_res, faction_data["buildings"]["Barracks"]["unit_list"]["Infantry"]["base_cost"][u_res])
		if(ttt == -1):
			decide_resource_goal(u_res)
			return
		think_timer.start(ttt)
		return


func __build():
	if prepared_building != null:
		## Currently building this building
		return
	## Attempt to place building
	var m_res = can_afford(faction_data["buildings"][target_item]["base_cost"])
	if m_res == null:
		prepared_building = gamescene.prep_other_building(self,target_item)
		prepared_building.rot = rng.randf_range(-180,180)
		prepared_building.visible = false
		match target_item:
			"Barracks","Trade_post", "Farm":	#Fort Buildings
				var frt = bases[rng.randi_range(0,bases.size()-1)]
				match(await find_build_spot(frt,prepared_building)):
					"clear":
						complete_goal()
					_:
						prepared_building.queue_free()
			"Lumber_mill","Mine_crystal","Mine_stone":	#Resource Node Buildings
				if(resource_locations[target_item].size() <= 0):
					## Don't know where resources are
					prepared_building.queue_free()
					_attempt_add("find",target_item)
					return
				var res_node = resource_locations[target_item][rng.randi_range(0,bases.size()-1)]
				match (await find_build_spot(res_node,prepared_building)):
					"clear":
						complete_goal()	
					"uncover_loc":
						## needs to move unit to target location
						prepared_building.queue_free()
						_attempt_add("uncover_loc", res_node)
					_:
						prepared_building.queue_free()
						_attempt_add("find",target_item)
	else:
		var ttb = build_patience_decide(m_res, faction_data["buildings"][target_item]["base_cost"][m_res])
		if(ttb == -1):
			decide_resource_goal(m_res)
		else:
			think_timer.start(ttb)
			return


func __uncover_loc():
	## Replace with heirarchy base Selection later
	var r_unit = units[rng.randi_range(0,units.size()-1)]	# Select random unit
	r_unit.set_mov_target(target_item.position)
	searching_units[r_unit] = target_item
	_defer_goal()
	if(!r_unit.uncovered_area.is_connected(unit_uncovered)):
		r_unit.uncovered_area.connect(unit_uncovered)


func __find():
	## Replace with hierarchy base Selection later
	var r_unit = units[rng.randi_range(0,units.size()-1)]	# Select random unit
	## Look for item randomly
	r_unit.ai_mode = "wandering_basic"
	searching_units[r_unit] = target_item
	var s_timer = Timer.new()
	r_unit.add_child(s_timer)
	## Start search patience timer
	match target_item:
		"Lumber_mill","Mine_crystal","Mine_stone":	#Resource Node Buildings
			s_timer.timeout.connect(searched_too_long.bind(s_timer,r_unit, resource_appropriate_nodes[target_item]))
			s_timer.start(res_search_patience)
		_:
			s_timer.timeout.connect(searched_too_long.bind(s_timer,r_unit, focused_enemy))
			s_timer.start(enemy_search_patience)
			
	_defer_goal()
	if(!r_unit.uncovered_area.is_connected(unit_uncovered)):
		r_unit.uncovered_area.connect(unit_uncovered)


func __attack():
	# No known enemy locations
	if (enemy_locations[focused_enemy].size() == 0):
		_attempt_add("find",focused_enemy)
		return
	var trgt_loc = enemy_locations[focused_enemy][rng.randi_range(0,enemy_locations[focused_enemy].size()-1)]
	for i in units:
		## Select all units
		##Maybe change this to keep defensive units
		selected_units.push_back(i)
	selected_units[0].declare_enemy(trgt_loc)
	if(selected_units.size() > 1):
		for j in range(1,selected_units.size()):
			selected_units[0].add_following(selected_units[j])
	selected_units = [] 


''' _think functions end '''
'''-------------------------------------------------------------------------------------'''
''' Patience start '''
## Decides whether waiting for resources for buildings
##
## returns -1 if wait would be too long
func build_patience_decide(res: String, amt: int) -> float:
	if(rpd[res] * build_patience < amt):
		return -1
	return (amt/rpd[res])*(global.DAY_LENGTH+global.NIGHT_LENGTH)


## Decides whether waiting for resources for troops
##
## returns -1 if wait would be too long
func troop_train_patience_decide(res: String, amt: int) -> float:
	if(rpd[res] * troop_train_patience < amt):
		return -1
	return (amt/rpd[res])*(global.DAY_LENGTH+global.NIGHT_LENGTH)


''' Patience end '''
'''-------------------------------------------------------------------------------------'''
''' Resource thinking start '''
## Add goal to get target resource
##
## returns true when goal created
func decide_resource_goal(res):
	match res:
		"wood":
			return _attempt_add("build","Lumber_mill",false)
		"stone":
			return _attempt_add("build","Mine_stone",false)
		"riches":
			return _attempt_add("build","Trade_post",false)
		"crystals":
			return _attempt_add("build","Mine_crystal",false)
		"food":
			return _attempt_add("build","Farm",false)


## Calc resources per day
func calc_res_rate():
	rpd = {
	"wood": 0,
	"stone": 0,
	"riches": 0,
	"crystals": 0,
	"food": 0}
	
	for b in buildings:
		if(b.has_method("generate_resource")):
			rpd[b.resource] += b.rpc * ((global.DAY_LENGTH+global.NIGHT_LENGTH)/b.generate_time)


func can_afford(res):
	for r in resources:
		if resources[r] < res[r] :
			return r
	return null


## Update expexcted units when building spawns units
func upate_exp_units(_bldg, unit):
	exp_pop -= unit.pop_cost


''' Resource thinking end '''
'''-------------------------------------------------------------------------------------'''
''' Building start '''
## Get sub-array of type of buildings
func get_target_buildings(bldg):
	var out = []
	for b in buildings:
		if b.type == bldg:
			out.push_back(b)
	return out


## Check area around target base for valid palce location
func find_build_spot(targ, bldg):
	var center = targ.position + Vector3(0,15,0)
	var attempts = 50
	var sure = false #not sure if avaialable area exists
	bldg.set_pos(center+Vector3(rng.randf_range(-targ.radius,targ.radius),0,rng.randf_range(-targ.radius,targ.radius)))
	while bldg.is_valid == false:
		var variation = Vector3(rng.randf_range(1,targ.radius),0,rng.randf_range(1,targ.radius))
		variation.y = ping_ground_depth(center + variation)
		if(!ping_ground(center + variation + Vector3(0,10,0)).name.contains("Floor")):
			#Stop trying to build on top of buildings
			continue
		var np = center + variation
		np.y -= center.y
		if await bldg.set_pos(np,true) == "cant see" and !sure:
			if(targ.has_meta("reveals_fog")):
				sure = true
				attempts += 1
			else:
				for ar in targ.local_area.get_overlapping_areas():
					if(ar.has_meta("fog_owner_id") and ar.get_meta("fog_owner_id") == actor_ID):
						sure = true
						attempts += 1
			if !sure:
				return "uncover_loc"  ## move troop to location to see it
		if(bldg.is_valid):
			place_building(prepared_building)
			return "clear"
		if !sure:
			attempts -= 1
		if(attempts < 0):
			return "find"
	return "clear"


## Check for Buildings in buildings array based on building type
func check_for_buildings(bldg: String):
	for b in buildings:
		if b.type == bldg:
			return true
	return false


## return ground at location
func ping_ground(pos):
	picker.position.x = pos.x
	picker.position.z = pos.z
	picker.force_raycast_update()
	return picker.get_collider()


func ping_ground_depth(pos):
	picker.position.x = pos.x
	picker.position.z = pos.z
	picker.force_raycast_update()
	return picker.get_collision_point().y


func place_building(bld):
	await super(bld)
	prepared_building = null
	bld.visible = true
	bld.spawned_unit.connect(upate_exp_units)
	calc_res_rate()


''' Building end '''
'''-------------------------------------------------------------------------------------'''
''' Goal Processing start '''
func __add_goal(goal: String, trgt, think_after : bool = true):
	goal_queue.push_back([current_goal,target_item])
	current_goal = goal
	target_item = trgt
	if(think_after):
		think_caller()


## Adds goal to queue or returns false when already waiting on goal
func _attempt_add(goal: String, trgt, think_after: bool = true):
	if(!deferred_goals.has([goal,trgt])):
		if(goal_queue.has([goal,trgt])):
			if([current_goal,target_item] != [goal,trgt]):
				goal_queue.pop_at(goal_queue.find([goal,trgt]))
		__add_goal(goal,trgt, think_after)
	return false


## Waiting for signal goals are stored here
func _defer_goal():
	if(deferred_goals.has(goal_queue[-1])):
		return false
	deferred_goals.push_back(goal_queue[-1])
	goal_queue.clear()
	current_goal = "ponder"
	target_item = "the world"
	return true


# Signal for goal is completed, tries to complete goal now
func _complete_deffered_goal(trgt):
	for i in range(deferred_goals.size()):
		if(typeof(deferred_goals[i][1]) == typeof(trgt) and deferred_goals[i][1] == trgt):
			var out = deferred_goals.pop_at(i)
			_attempt_add(out[0],out[1])
			return


## Complete goal and get next in queue
func complete_goal():
	var erase = target_item
	if(goal_queue.size()>0):
		var n = goal_queue.pop_back()
		current_goal = n[0]
		target_item = n[1]
		for g in range(goal_queue.size()):
			if(typeof(goal_queue[g]) == typeof(erase) and goal_queue[g] == erase):
				goal_queue.pop_at(g)
		return


''' Goal Processing end '''
'''-------------------------------------------------------------------------------------'''
''' Unit Commanding start '''

## Unit found target
func unit_uncovered(unit, area):
	if(searching_units.has(unit)): #Found target location
		if(typeof(searching_units[unit]) == TYPE_STRING):
			var cur_trgt  = resource_appropriate_nodes[searching_units[unit]]
			if(area.get_parent().name.contains(cur_trgt)):
				match cur_trgt:
					"Forest","Crystal_deposit","Stone_deposit":
						resource_locations[searching_units[unit]].push_back(area.get_parent())
					_:
						enemy_locations[searching_units[unit]] = area.get_parent()
				_complete_deffered_goal(searching_units[unit])
				searching_units.erase(unit)
		elif(searching_units[unit].has_meta("res_building")):
			## Was looking for building
			if(area.get_parent().has_meta("res_building")):
				if(searching_units[unit].has_meta("res_building") and area.get_parent().get_meta("res_building") == searching_units[unit].get_meta("res_building")):
					#Found target node
					_complete_deffered_goal(searching_units[unit].get_meta("res_building"))
					searching_units.erase(unit)
		else:
			# Was looking for player
			if(area.get_parent().get_parent().has_meta("show_base_radius")):
				if(area.get_parent().get_parent().actor_owner == searching_units[unit]):
					#Found target node
					enemy_locations[searching_units[unit]].push_back(area.get_parent().get_parent())
					area.get_parent().get_parent().died.connect(clear_destroyed_building.bind(searching_units[unit],area.get_parent().get_parent()))
					_complete_deffered_goal(searching_units[unit])
					searching_units.erase(unit)


''' Unit Commanding end '''
'''-------------------------------------------------------------------------------------'''
''' Enemy targeting start '''

func clear_destroyed_building(actor_owner, bldg):
	enemy_locations[actor_owner].pop_at(enemy_locations[actor_owner].find(bldg))

# AI can't find location so tell AI where it is
func searched_too_long(timer, unit, target):
	timer.stop()
	timer.queue_free()
	if(typeof(target) == TYPE_STRING):
		for nod in gamescene.get_child(2).get_children():
			if nod.name.contains(target):
				unit.set_mov_target(nod.position)
	else:
		for bldg in gamescene.world_buildings:
			if bldg.actor_owner == target:
				unit.set_mov_target(bldg.position + Vector3(rng.randi_range(-10,10),0,rng.randi_range(-10,10)))


''' Enemy targeting end '''
