extends game_actor

class_name enemy_controller


@onready var rng = RandomNumberGenerator.new()
var think_timer : Timer

## Goal processing variables
var current_goal : String
var goal_queue := []
var target_item : String 

## Personality variables
var speed_of_thought = 5
var few_troops_threshold = 5


## Called when the node enters the scene tree for the first time.
func _ready():
	goal_queue.push_back(["get units",""])
	goal_queue.push_back(["get units",""])
	current_goal = "get units"
	think_timer = Timer.new()
	add_child(think_timer)
	think_timer.timeout.connect(think)
	think_timer.start(speed_of_thought)


func think():
	match current_goal:
		"get units":
			if check_for_buildings("Barracks") == false:
				add_goal("build","Barracks")
				return
			if pop < few_troops_threshold:
				var barr = get_target_buildings("Barracks")
				var trgt = barr[rng.randi_range(0,barr.size()-1)]
				if trgt.use("Infantry"):
					complete_goal()
		"build":
			## Error checking for building name
			if gamescene.loaded_buildings[actor_ID].has(target_item) == false:
				print_debug("Error invalid building name")
				current_goal = "sleeping"
				target_item = "none"
			## Attempt to place building
			if gamescene.loaded_buildings[actor_ID][target_item].instantiate().can_afford(resources):
				var frt = bases[rng.randi_range(0,bases.size()-1)]
				var bldg = gamescene.prep_other_building(self,target_item)
				if(find_build_spot(frt,bldg)):
					place_building(gamescene.world.get_region(bldg.position),bldg)
					complete_goal()
				else:
					add_goal("build","Fort")
					return
					
		_:
			print("sleeping")
	think_timer.start(speed_of_thought)


## Get sub-array of type of buildings
func get_target_buildings(bldg):
	var out = []
	for b in buildings:
		if b.type == bldg:
			out.push_back(b)
	return out


## Check area around target base for valid palce location
func find_build_spot(frt, bldg):
	var center = frt.position
	var attempts = 50
	bldg.set_pos(center+Vector3(rng.randf_range(-frt.radius,frt.radius),0,rng.randf_range(-frt.radius,frt.radius)))
	while bldg.is_valid == false:
		bldg.set_pos(center+Vector3(rng.randf_range(-frt.radius,frt.radius),0,rng.randf_range(-frt.radius,frt.radius)))
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
	think()

func complete_goal():
	if(goal_queue.size()>0):
		current_goal = goal_queue.back()[0]
		target_item = goal_queue.back()[1]
		goal_queue.pop_back()
		return
