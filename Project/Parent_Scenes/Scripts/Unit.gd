extends CharacterBody3D


class_name Unit_Base


#signals
signal selected


const MAX_SPEED = 10
const ACCEL = 3
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


@onready var nav_agent: NavigationAgent3D = get_node("NavigationAgent3D")
@onready var unit_radius = $CollisionShape3D.shape.get_radius()
var actor_owner
var followers: Array
var unit_name: String
var is_selected: bool

var rng = RandomNumberGenerator.new()

var intial_path_dist := 0.1
var unit_list
var pop_cost := 0
var res_cost := {"wood": 0,
"stone": 0,
"riches": 10,
"crystals": 10,
"food": 0}

var target_enemy: Unit_Base
var target_follow: Unit_Base


func _ready():
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	
	nav_agent.waypoint_reached.connect(waypoint)
	
	call_deferred("actor_setup")


func actor_setup():
	await get_tree().physics_frame


func set_mov_target(mov_tar: Vector3):
	nav_agent.set_target_position(mov_tar)
	intial_path_dist = nav_agent.distance_to_target()


## Set folowing units
func set_following(units):
	followers = units
	for i in units:
		if(i != self):
			i.target_follow = self


## Add folowing units
func add_following(unit):
	followers.push_back(unit)
	unit.target_follow = self


func _physics_process(delta):	
	if nav_agent.is_navigation_finished():
		return
		
	var current_agent_position: Vector3 = global_transform.origin
	var next_path_position: Vector3 = nav_agent.get_next_path_position()
	var new_velocity: Vector3 = next_path_position - current_agent_position
	#Accelerate and decelerrate
	if nav_agent.distance_to_target() > intial_path_dist*.1 or nav_agent.distance_to_target() > 3:
		new_velocity = lerp_start(new_velocity, delta)
	else:
		new_velocity = lerp_stop(new_velocity, delta)
		
	set_velocity(new_velocity)
	move_and_slide()


#speed up when starting movement
func lerp_start(nv, dx):
	nv = nv.normalized()* MAX_SPEED
	nv = lerp(velocity,nv,dx*ACCEL)
	return nv


#speed up when starting movement
func lerp_stop(nv, dx):
	nv = nv.normalized() * 0.2
	nv = lerp(velocity,nv,dx*ACCEL)
	return nv


#check target position for othe runits
func check_pos(pos):
	var new_pos = pos
	for i in unit_list:
		if i == self:
			pass
		elif (i.position.distance_to(new_pos) <= unit_radius*3):
			new_pos = check_pos(new_pos + Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)))
	return new_pos


## Call to see if purchasable
func can_afford(builder_res, ):
	for res in builder_res:
		if builder_res[res] < res_cost[res] :
			return false
	return true


## Unit is selected and make selection visible
func select(state : bool = true):
	$Valid_Region.visible = state

###SIGNAL FUNCTIONS##
#signal being selected on click
func _on_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
		selected.emit(self)


func _on_navigation_agent_3d_navigation_finished():
	var targ = check_pos(position)
	if(targ.is_equal_approx(position) == false):
		set_mov_target(targ)
	if followers.size() > 0:
		for i in followers:
			i.set_mov_target(position)
			i.target_follow = null
	if target_follow != null:
		set_mov_target(target_follow.position)


func _on_NavigationAgent_velocity_computed(_safe_velocity):
	#velocity = safe_velocity
	move_and_slide()


func waypoint(_details):
	if followers.size() > 0:
		for i in followers:
			i.set_mov_target(nav_agent.get_next_path_position())
