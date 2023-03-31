extends CharacterBody3D


const SPEED = 5.0
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

#signals
signal selected


func _ready():
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	
	call_deferred("actor_setup")

func actor_setup():
	await get_tree().physics_frame
	
	move_and_slide()	
	
	
	set_mov_target(global_position)
	
func set_mov_target(mov_tar: Vector3):
	nav_agent.set_target_position(mov_tar)
	
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
	if get_slide_collision_count() > 0:		
		for i in range(get_slide_collision_count()):
			print(get_slide_collision(i).get_collider().name)

#signal being selected on click
func _on_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
		selected.emit(self)
