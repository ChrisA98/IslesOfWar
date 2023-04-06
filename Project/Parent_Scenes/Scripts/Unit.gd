extends CharacterBody3D


class_name Unit_Base


const MAX_SPEED = 10
const ACCEL = 3
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var unit_radius = $CollisionShape3D.shape.get_radius()
var rng = RandomNumberGenerator.new()


var intial_path_dist = 0
var unit_list


#signals
signal selected


func _ready():
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	
	call_deferred("actor_setup")


func actor_setup():
	await get_tree().physics_frame


func set_mov_target(mov_tar: Vector3):
	var targ = check_pos(mov_tar+Vector3(0,.5,0))
	while mov_tar != targ:
		mov_tar = targ
		targ = check_pos(mov_tar)
	nav_agent.set_target_position(mov_tar)
	intial_path_dist = nav_agent.distance_to_target()


func _physics_process(delta):	
	
	if nav_agent.is_navigation_finished():
		return
		
	var current_agent_position: Vector3 = global_transform.origin
	var next_path_position: Vector3 = nav_agent.get_next_path_position()
	var new_velocity: Vector3 = next_path_position - current_agent_position
	#Accelerate and decelerrate
	if nav_agent.distance_to_target() > intial_path_dist*.1:
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


#signal being selected on click
func _on_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
		selected.emit(self)


func _on_navigation_agent_3d_navigation_finished():
	var targ = check_pos(position)
	if(targ.is_equal_approx(position) == false):
		set_mov_target(targ)
	set_velocity(Vector3(0,0,0))
