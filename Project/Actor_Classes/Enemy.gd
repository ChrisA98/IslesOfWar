extends game_actor

class_name enemy_controller

const resource_appropriate_nodes = {"Lumber_mill" : "Forest",
"Mine_stone" : "Stone_deposit",
"Mine_crystal" : "Crystal_depost"}

@onready var rng = RandomNumberGenerator.new()
@onready var global = get_node("/root/Global_Vars")
var think_timer : Timer
var picker : RayCast3D	#Raycast for checking locations
## Knowledgebase
var resource_locations := {}
var enemy_locations := {}

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
var exp_pop := 0 #expected population after training current users
var selected_units = []
var searching_units = {}

## Goal processing variables
var current_goal : String
var goal_queue := []
var goals_waiting := []
var target_item 
var focused_enemy #Current enemy targeted

## Personality variables
var troop_train_patience = .1
var build_patience = .1
var search_patience = 5
var speed_of_thought = 1
var few_troops_threshold = 2
var min_troop_attack = 10
var goal_hierarchy = [
	"attack",
	"expand",
	"explore"
]


## Called when the node enters the scene tree for the first time.
func _ready():
	add_child(RayCast3D.new())
	picker = get_child(0)
	picker.position.y = 100
	picker.target_position.y = -200
	
	current_goal = "ponder"
	
	## Get taget enemy
	focused_enemy = self	#kick off loop
	while focused_enemy == self:
		focused_enemy = gamescene.game_actors[rng.randi_range(0,gamescene.game_actors.size()-1)] #get random target
		
	think_timer = Timer.new()
	add_child(think_timer)
	think_timer.timeout.connect(think_caller)
	think_timer.start(4)
	
	## -- DEBUG/TESTING STUFF -- ##
	resource_locations["Lumber_mill"] = []
	resource_locations["Mine_stone"] = [gamescene.find_child("World").get_children()[5]]
	resource_locations["Mine_crystal"] = [gamescene.find_child("World").get_children()[6]]


func think_caller():
	call_deferred("_think")


## Decides how to accomplish a goal
func _think():
	think_timer.stop()
	match current_goal:
		"get units":
			if check_for_buildings("Barracks") == false:
				_attempt_add("build","Barracks")
				return
			var barr = get_target_buildings("Barracks")
			var trgt = barr[rng.randi_range(0,barr.size()-1)]
			var u_res = can_afford(faction_data["buildings"]["Barracks"]["unit_list"]["Knight"]["base_cost"])
			if u_res == null:
				if trgt.push_train_queue("Knight"):
					exp_pop += faction_data["buildings"]["Barracks"]["unit_list"]["Knight"]["pop_cost"]
					complete_goal()
				else:
					_attempt_add("build","Barracks")
					return
			else:
				var ttt = troop_train_patience_decide(u_res, faction_data["buildings"]["Barracks"]["unit_list"]["Knight"]["base_cost"][u_res])
				if(ttt == -1):
					decide_resource_goal(u_res)
					return
				think_timer.start(ttt)
				return
		"build":
			## Attempt to place building
			var m_res = can_afford(faction_data["buildings"][target_item]["base_cost"])
			if m_res == null:
				var bldg = gamescene.prep_other_building(self,target_item)
				bldg.visible = false
				match target_item:
					"Barracks","Trade_post", "Farm":	#Fort Buildings
						var frt = bases[rng.randi_range(0,bases.size()-1)]
						if(await find_build_spot(frt,bldg)):
							place_building(ping_ground(bldg.position).get_parent().get_groups()[0],bldg)
							complete_goal()
						else:
							bldg.queue_free()
							_attempt_add("build","Farm")
							return
					"Lumber_mill","Mine_crystal","Mine_stone":	#Resource Node Buildings
						if(resource_locations[target_item].size() <= 0):
							## don't know where to look for resources
							bldg.queue_free()
							_attempt_add("find",target_item)
							return
						var res_node = resource_locations[target_item][rng.randi_range(0,bases.size()-1)]
						match (await find_build_spot(res_node,bldg)):
							"clear":
								place_building(ping_ground(bldg.position).get_parent().get_groups()[0],bldg)
								complete_goal()	
							"uncover_loc":
								## needs to move unit to target location
								bldg.queue_free()
								_attempt_add("uncover_loc", res_node)
								return
							_:
								bldg.queue_free()
								_attempt_add("find",target_item)
								return
			else:
				var ttb = build_patience_decide(m_res, faction_data["buildings"][target_item]["base_cost"][m_res])
				if(ttb == -1):
					decide_resource_goal(m_res)
				else:
					think_timer.start(ttb)
					return
		"uncover_loc":
			## Replace with heirarchy base Selection later
			var r_unit = units[rng.randi_range(0,units.size()-1)]	# Select random unit
			r_unit.set_mov_target(target_item.position)
			searching_units[r_unit] = target_item
			_defer_goal()
			if(!r_unit.uncovered_area.is_connected(unit_uncovered)):
				r_unit.uncovered_area.connect(unit_uncovered)
		"find":
			## Replace with heirarchy base Selection later
			var r_unit = units[rng.randi_range(0,units.size()-1)]	# Select random unit
			if(r_unit.ai_mode.contains("idle")):	#Check if unit is currently not busy
				## Look for item randomly
				r_unit.ai_mode = "wandering_basic"
				searching_units[r_unit] = target_item
				var s_timer = Timer.new()
				r_unit.add_child(s_timer)
				s_timer.timeout.connect(searched_too_long.bind(s_timer,r_unit, resource_appropriate_nodes[target_item]))
				s_timer.start(search_patience)
				_defer_goal()
				if(!r_unit.uncovered_area.is_connected(unit_uncovered)):
					r_unit.uncovered_area.connect(unit_uncovered)
			else:
				#units are busy, so you need another one
				_attempt_add("get units","Scout")
		_:
			ponder()
	think_timer.start(speed_of_thought)


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


## add goal to get target resource
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
		if bldg.set_pos(np) == "cant see" and !sure:
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
		await get_tree().physics_frame
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


func __add_goal(goal: String, trgt, think_after : bool = true):
	goal_queue.push_back([current_goal,target_item])
	current_goal = goal
	target_item = trgt
	if(think_after):
		think_caller()


## Adds goal to queue or returns false when already waiting on goal
func _attempt_add(goal: String, trgt, think_after: bool = true):
	if(!goals_waiting.has([goal,trgt])):
		if(goal_queue.has([goal,trgt])):
			if([current_goal,target_item] != [goal,trgt]):
				goal_queue.pop_at(goal_queue.find([goal,trgt]))
		__add_goal(goal,trgt, think_after)
		if think_after:
			return true
	think_timer.start(speed_of_thought)
	return false


## Waiting for signal goals are stored here
func _defer_goal():
	if(goals_waiting.has(goal_queue[1])):
		return false
	goals_waiting.push_back(goal_queue[1])
	goal_queue.clear()
	current_goal = "ponder"
	think_timer.start(speed_of_thought)
	return true


# Signal for goal is completed, tries to complete goal now
func _complete_deffered_goal(trgt):
	for i in range(goals_waiting.size()):
		if(goals_waiting[i][1] == trgt):
			var out = goals_waiting.pop_at(i)
			_attempt_add(out[0],out[1])


## complete goal and get next in queue
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


func can_afford(res):
	for r in resources:
		if resources[r] < res[r] :
			return r
	return null


func place_building(grp, bld):
	super(grp, bld)
	bld.visible = true
	calc_res_rate()


## Consider next plan after goals queue finished
##
## Return false if think not called
func ponder():
	if(goal_queue.size() > 100):
		goal_queue = [["do_nothing","nothing"]]
		print_debug("goal overflow error")
	
	## Calculate resource rate
	calc_res_rate()
	
	## Get resource building if no income of that source exists
	for res in rpd:
		if rpd[res] == 0:
			decide_resource_goal(res)
	
	## Ensure minimum units are met
	if exp_pop < few_troops_threshold:
		if _attempt_add("get units","something"): #add unit build decision code here
			return true
	
	for goal in goal_hierarchy:
		match goal:
			"attack":
				## Check if they have enough units
				if(pop < min_troop_attack):
					if(exp_pop < min_troop_attack):
						if _attempt_add("get units","something"): #add unit build decision code here
							return true
				else:
					for i in units:
						## Select all units
						##Maybe change this to keep defensive units
						selected_units.push_back(i)
					selected_units[0].declare_enemy(gamescene.world_buildings[1])
					if(selected_units.size() > 1):
						for j in range(1,selected_units.size()):
							selected_units[0].add_following(selected_units[j])
					selected_units = [] 
			_:
				pass
	return false


## calc resources per day
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


# AI can't find location so tell AI
func searched_too_long(timer, unit, target):
	timer.stop()
	timer.queue_free()
	for nod in gamescene.get_child(2).get_children():
		if nod.name.contains(target):
			unit.set_mov_target(nod.position)


## Unit found target
func unit_uncovered(unit, area):
	if(searching_units.has(unit)): #Found target location
		if(typeof(searching_units[unit]) == TYPE_STRING):
			var cur_trgt  = resource_appropriate_nodes[searching_units[unit]]
			if(area.get_parent().name.contains(cur_trgt)):
				match cur_trgt:
					"Forest","Crystal_depost","Stone_depost":
						resource_locations[searching_units[unit]].push_back(area.get_parent())
					_:
						enemy_locations[searching_units[unit]] = area.get_parent()
				_complete_deffered_goal(searching_units[unit])
		else:
			if(area.get_parent().has_meta("res_building")):
				if(searching_units[unit].has_meta("res_building") and area.get_parent().get_meta("res_building") == searching_units[unit].get_meta("res_building")):
					#Found target node
					_complete_deffered_goal(searching_units[unit].get_meta("res_building"))
