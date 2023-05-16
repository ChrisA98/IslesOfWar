extends game_actor

class_name enemy_controller


@onready var rng = RandomNumberGenerator.new()
@onready var global = get_node("/root/Global_Vars")
var think_timer : Timer
var picker : RayCast3D	#Raycast for checking locations

## Knowledgebase
var resource_locations := {}
var enemy_locations := {}
var rpd := {
"wood": 0,
"stone": 0,
"riches": 0,
"crystals": 0,
"food": 0}

## Goal processing variables
var current_goal : String
var goal_queue := []
var target_item : String 

## Personality variables
var speed_of_thought = 3
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
	think_timer = Timer.new()
	add_child(think_timer)
	think_timer.timeout.connect(think_caller)
	think_timer.start(speed_of_thought)
	
	## -- DEBUG/TESTING STUFF -- ##
	resource_locations["Lumber_mill"] = [gamescene.find_child("World").get_children()[4]]
	resource_locations["Mine_stone"] = [gamescene.find_child("World").get_children()[5]]
	resource_locations["Mine_crystal"] = [gamescene.find_child("World").get_children()[6]]


func think_caller():
	call_deferred("think")


#dont call directly
func think():
	match current_goal:
		"get units":
			if check_for_buildings("Barracks") == false:
				add_goal("build","Barracks")
				return
			var barr = get_target_buildings("Barracks")
			var trgt = barr[rng.randi_range(0,barr.size()-1)]
			var u_res = can_afford(faction_data["buildings"]["Barracks"]["unit_list"]["Knight"]["base_cost"])
			if trgt.use("Infantry"):
				complete_goal()
				return
			else:
				decide_resource_goal(u_res)
				return
		"build":
			## Error checking for building name
			if gamescene.loaded_buildings[actor_ID].has(target_item) == false:
				print_debug("Error invalid building name: " + target_item)
				current_goal = "sleeping"
				target_item = "none"
			## Attempt to place building
			var m_res = can_afford(faction_data["buildings"][target_item]["base_cost"])
			if m_res == null:
				var bldg = gamescene.prep_other_building(self,target_item)
				bldg.visible = false
				match target_item:
					"Barracks","Trade_post":
						var frt = bases[rng.randi_range(0,bases.size()-1)]
						if(await find_build_spot(frt,bldg)):
							place_building(ping_ground(bldg.position).get_parent().get_groups()[0],bldg)
							complete_goal()
						else:
							bldg.queue_free()
							add_goal("build","Fort")
							return
					"Lumber_mill","Mine_crystal","Mine_stone":
						var res_node = resource_locations[target_item][rng.randi_range(0,bases.size()-1)]
						if(await find_build_spot(res_node,bldg)):
							place_building(ping_ground(bldg.position).get_parent().get_groups()[0],bldg)
							complete_goal()
						else:
							bldg.queue_free()
							add_goal("find",target_item)
							return
			else:
				decide_resource_goal(m_res)
				return
		_:
			if !ponder():
				return
	think_timer.start(speed_of_thought)


## add goal to get target resource
func decide_resource_goal(res):
	match res:
		"wood":
			add_goal("build","Lumber_mill")
			return
		"stone":
			add_goal("build","Mine_stone")
			return
		"riches":
			add_goal("build","Trade_post")
			return
		"crystals":
			add_goal("build","Mine_crystal")
			return


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
	bldg.set_pos(center+Vector3(rng.randf_range(-targ.radius,targ.radius),0,rng.randf_range(-targ.radius,targ.radius)))
	while bldg.is_valid == false:
		var variation = Vector3(rng.randf_range(-targ.radius,targ.radius),0,rng.randf_range(-targ.radius,targ.radius))
		variation = ping_ground(variation).position
		bldg.set_pos(center + variation)
		await get_tree().physics_frame
		attempts -= 1
		if(attempts < 0):
			return false
	return true


## Check for Buildings in buildings array based on building type
func check_for_buildings(bldg: String):
	for b in buildings:
		if b.type == bldg:
			return true
	return false


func add_goal(goal: String, trgt: String):	
	goal_queue.push_back([current_goal,target_item])
	current_goal = goal
	target_item = trgt
	think_caller()


## complete goal and get next in queue
func complete_goal():
	if(goal_queue.size()>0):
		current_goal = goal_queue.back()[0]
		target_item = goal_queue.back()[1]
		goal_queue.pop_back()
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


## Consider next plan after goals queue finished
func ponder():
	print("pondering...")
	## Ensure minimum units are met
	if units.size() < few_troops_threshold:
		add_goal("get units","something")#add unit build decision code here
		return true
	## Calculate resource rate
	calc_res_rate()
	
	## Emergency resource getting
	
	for goal in goal_hierarchy:
		match goal:
			"attack":
				if(units.size() < min_troop_attack):
					add_goal("get units","something")#add unit build decision code here
					return
				else:
					## HOW DO ATTACK??
					pass 
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

