extends Node3D

#Camera stats
var zoom = 10

#Movement vars
var speed = Vector3()
var maxSpeed = 1
var maxSpeed_run = 3
var maxSpeed_norm = .8

#Physics vars
var velocity = Vector3()
var key_direct = Vector3()
var mouse_direct = Vector3()
var tot_direct = Vector3()
var accel = 2

#REF vars
@onready var cam = $Player_view
@onready var game_window = $"../../UI_Node/Viewport_Sectons"
var menu_buildings


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED) 


func _input(event):	
	if event is InputEventMouseMotion:
		#Hide moue off screen
		if get_viewport().get_mouse_position().x > (get_viewport().size.x-8) or get_viewport().get_mouse_position().y > (get_viewport().size.y-8):
			Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED) 
			
	#only read mouse position on screen while in game window
	#scroll wheel input
	if Input.is_action_just_released("scroll_up") and zoom < 20:
		zoom += .25
	if event.is_action("scroll_down") and zoom > 0:
		zoom -= .25
	cam.position = Vector3(0,25-zoom,25-zoom)
	
	
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
		
	
	velocity = velocity.lerp(tot_direct * maxSpeed, accel * delta)
	speed.z = velocity.z
	speed.x = velocity.x
	
	translate(speed)
	
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
