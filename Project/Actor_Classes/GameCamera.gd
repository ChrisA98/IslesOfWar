extends Node3D

var rng = RandomNumberGenerator.new()

#Camera stats
var zoom = 20

#Movement vars
var speed = Vector3()
var maxSpeed = 1
var maxSpeed_run = 3
var maxSpeed_norm = 1.2
var world_bounds := Vector2i(500,500)

#Physics vars
var velocity = Vector3()
var key_direct = Vector3()
var mouse_direct = Vector3()
var tot_direct = Vector3()
var accel = 2

#REF vars
@onready var gamescene = $"../.."
@onready var cam = get_node("./Player_view")
@onready var ground_check = get_node("../RayCast3D")
@onready var game_window = $"../../UI_Node/Viewport_Sectons"
var menu_buildings


func _ready():
	ground_check.position.x = position.x
	ground_check.position.z = position.z
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED) 


func _input(event):
	if event is InputEventMouseMotion:
		## Selector management
		var on_map = true
		for m in get_tree().get_nodes_in_group("uses_scroll"):
			if m.has_mouse:
				on_map = false
		if on_map:
			var to = cam.project_ray_normal(event.position) * 1000
			$Player_view/selector_collidor.target_position = to - position
			if $Player_view/selector_collidor.is_colliding():
				print($Player_view/selector_collidor.get_collision_point())
				$selector.position = $Player_view/selector_collidor.get_collision_point()
			else:
				on_map = false
			
		$selector.visible = on_map	
		#Hide mouse off screen
		if get_viewport().get_mouse_position().x > (get_viewport().size.x-8) or get_viewport().get_mouse_position().y > (get_viewport().size.y-8):
			Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
		elif(gamescene.click_mode != "build"):
			Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED) 
		## Rotate Camera
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			rotate_y(event.get_relative().x/100)
			#$Visual_Ground.rotate_y((event.get_relative().x*-1)/100)
			$"../../UI_Node/Minimap/Minimap_Container".set_rotation_degrees(rotation_degrees.y)
			
	#only read mouse position on screen while in game window
	#scroll wheel input
	if Input.is_action_just_released("scroll_up") and zoom > 0:
		for m in get_tree().get_nodes_in_group("uses_scroll"):
			if m.has_mouse:
				return
		zoom -= 5
	if event.is_action("scroll_down") and zoom < 50:
		for m in get_tree().get_nodes_in_group("uses_scroll"):
			if m.has_mouse:
				return
		zoom += 5
	
	if Input.is_action_just_released("reset_map_rot"):
		rotation_degrees = Vector3.ZERO
		$"../../UI_Node/Minimap/Minimap_Container".set_rotation_degrees(0)
		
	
	#close game, TESTING ONLY
	if event.is_action_pressed(("esc")):
		if(check_menus()):
			$"../../UI_Node".close_menus()
		else:
			get_tree().quit()
	
	if event.is_action_pressed(("sprint")):
		maxSpeed = maxSpeed_run
	if event.is_action_released(("sprint")):
		maxSpeed = maxSpeed_norm


func check_menus():
	for i in $"../../UI_Node".menus:
		if i.visible:
			return true
	return false


func _physics_process(delta):
	
	if Input.is_action_pressed(("cam_move_forward")):
		key_direct -= transform.basis.z
	if Input.is_action_pressed(("cam_move_backward")):
		key_direct += transform.basis.z
	if Input.is_action_pressed(("cam_move_left")):
		key_direct -= transform.basis.x
	if Input.is_action_pressed(("cam_move_right")):
		key_direct += transform.basis.x
	
	if(key_direct.length()>0):
		tot_direct	= key_direct.normalized()
	else:
		tot_direct	= mouse_direct.normalized()
		
	# Add zoom
	ground_check.position.x = position.x
	ground_check.position.z = position.z
	ground_check.force_raycast_update()
	var height = ground_check.get_collision_point().y
	var trgt = height+zoom
	var distance_to_trgt = abs(position.y - trgt)
	
	## Move ground render sqruare
	var zoom_offset = position.direction_to($Player_view.global_position)*height*-5
	$"../Visual_Ground".position = position+zoom_offset - Vector3(fmod(position.x+zoom_offset.x,4),0,fmod(position.z+zoom_offset.z,4))
	
	if(ground_check.is_colliding()):
		velocity.y = clamp((position.y - trgt)*-1,-1,1)
	elif(distance_to_trgt or !ground_check.is_colliding()):
		velocity.y = 1
	
	velocity = velocity.lerp(tot_direct * maxSpeed, accel * delta)
	speed.z = velocity.z
	speed.x = velocity.x
	speed = speed.rotated(Vector3.UP,deg_to_rad(-get_rotation_degrees().y))
	speed.y = velocity.y
	
	translate(speed)
	
	## Arrest motion at map edge
	if abs(position.x) > world_bounds.x or abs(position.z) > world_bounds.y:
		translate(-speed)
		velocity = Vector3.ZERO
	
	key_direct = Vector3()
	tot_direct = Vector3()
	


#####Control Mouse based camera movement
func _on_left_bar_mouse_entered():
	mouse_direct.x = -1


func _on_right_bar_mouse_entered():
	mouse_direct.x = 1


func _on_top_bar_mouse_entered():
	mouse_direct.z = -1


func _on_bottom_bar_mouse_entered():
	mouse_direct.z = 1


func _on_left_bar_mouse_exited():
	mouse_direct.x = 0


func _on_right_bar_mouse_exited():
	mouse_direct.x = 0


func _on_top_bar_mouse_exited():
	mouse_direct.z = 0


func _on_bottom_bar_mouse_exited():
	mouse_direct.z = 0
