extends Node3D

var direct := Vector3()
var velocity:= Vector3()
var speed := Vector3()
var max_speed = 5
var accel = 8


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
	
	## align editor overlay viewport with main camera
	$"../UI/editor_overlay_viewport/SubViewport/editor_overlay".transform = $editor_preview.global_transform
	
	## Arrest motion at map edge
	if abs(position.x) > Global_Vars.heightmap_size*.75 or abs(position.z) > Global_Vars.heightmap_size*.75:
		translate(-speed)
		velocity = Vector3.ZERO
	
	direct = Vector3()
	

func _switch_cam(id:int):
	if id == 0:
		$editor_preview.make_current()
		return
	$environment_prev.make_current()


