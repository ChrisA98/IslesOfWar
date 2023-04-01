extends CharacterBody3D


const SPEED = 5.0
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var nav_obs: NavigationObstacle3D = $NavigationObstacle3D
@onready var unit_radius = $CollisionShape3D.shape.get_radius()
var unit_list
var rng = RandomNumberGenerator.new()


#signals
signal selected


func _ready():
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	
	call_deferred("actor_setup")

func actor_setup():
	await get_tree().physics_frame
	
func set_mov_target(mov_tar: Vector3):
	nav_agent.set_target_position(mov_tar+Vector3(0,.5,0))


func set_navigation_map(rid):
	pass
	# nav_obs.set_navigation_map(rid)
	
func _physics_process(delta):	
	
	if nav_agent.is_navigation_finished():
		return
		
	var current_agent_position: Vector3 = global_transform.origin
	var next_path_position: Vector3 = nav_agent.get_next_path_position()
	
	var new_velocity: Vector3 = next_path_position - current_agent_position
	new_velocity = new_velocity.normalized()
	new_velocity = new_velocity * SPEED
	
	set_velocity(new_velocity)
	move_and_slide()

#signal being selected on click
func _on_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
		selected.emit(self)


func _on_navigation_agent_3d_navigation_finished():
	for i in unit_list:
		if i.get_children()[0] == self:
			break
		if i.get_children()[0].position.distance_to(position) <= unit_radius*2:
			set_mov_target(global_position + Vector3(rng.randf_range(-3,3),0,rng.randf_range(-3,3)))
