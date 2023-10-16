extends Node3D

var direct := Vector3()
var velocity:= Vector3()
var speed := Vector3()
var world_bounds := Vector2i(500,500)
var max_speed = 5
var accel = 8

func _input(event):		
	if event.is_action_pressed("rmb"):
		_switch_cam()
	
	#close game, TESTING ONLY
	if event.is_action_pressed(("esc")):
		get_tree().quit()


func _physics_process(delta):
	
	if Input.is_action_pressed("editor_cam_rotate_r"):
		rotate(Vector3.UP,2*-delta)
	if Input.is_action_pressed("editor_cam_rotate_l"):
		rotate(Vector3.UP,2*delta)
		
	if Input.is_action_pressed(("cam_move_forward")):
		direct -= transform.basis.z
	if Input.is_action_pressed(("cam_move_backward")):
		direct += transform.basis.z
	if Input.is_action_pressed(("cam_move_left")):
		direct -= transform.basis.x
	if Input.is_action_pressed(("cam_move_right")):
		direct += transform.basis.x
	if Input.is_action_pressed(("editor_cam_ascend")):
		direct += transform.basis.y
	if Input.is_action_pressed(("editor_cam_descend")):
		direct -= transform.basis.y
	
	direct	= direct.normalized()
	
	
	velocity = velocity.lerp(direct * max_speed, accel * delta)
	speed.z = velocity.z
	speed.x = velocity.x
	speed = speed.rotated(Vector3.UP,deg_to_rad(-get_rotation_degrees().y))
	speed.y = velocity.y
	
	translate(speed)
	
	## Arrest motion at map edge
	#if abs(position.x) > world_bounds.x or abs(position.z) > world_bounds.y:
		#translate(-speed)
		#velocity = Vector3.ZERO
	
	direct = Vector3()
	

func _switch_cam():
	if $editor_preview.current:
		$environment_prev.make_current()
		return
	$editor_preview.make_current()


