extends Node3D

#custom signals
signal activated

#REF vars
@onready var mesh = $MeshInstance3D
@onready var collision_box = $StaticBody3D/CollisionShape3D
@onready var static_body = $StaticBody3D
var invalid_mat
var valid_mat

#can be placed
var is_valid
#is snapping to grid
var snapping = 0

var collision_buffer = 0

func _ready():
	invalid_mat = preload("res://Materials/preview_building_invalid.tres")
	valid_mat = preload("res://Materials/preview_building_valid.tres")
	
func init(pos, snap):
	position = pos
	mesh.transparency = .55
	mesh.set_surface_override_material(0, valid_mat)
	static_body.set_ray_pickable(false)
	
	set_snap(snap)
	
func set_pos(pos):
	position = pos + Vector3(0,(scale.y/2)*.95,0)
	if snapping > 1:
		position.x = ceil(position.x/snapping)*snapping
		position.z = ceil(position.z/snapping)*snapping
	if check_collision(collision_buffer):
		make_invalid()
	else:
		make_valid()

func place():
	mesh.set_surface_override_material(0, null)
	mesh.transparency = 0
	static_body.set_ray_pickable(true)
	static_body.set_collision_layer_value(1,true)
	
func make_valid():
	is_valid = true
	mesh.set_surface_override_material(0, valid_mat)

func make_invalid():
	is_valid = false
	mesh.set_surface_override_material(0, invalid_mat)

func check_collision(buff_range):	
	if static_body.test_move(transform.scaled_local(Vector3(.9,.9,.9)), Vector3(0,0,buff_range)):
		return true
	elif static_body.test_move(transform.scaled_local(Vector3(.9,.9,.9)), Vector3(0,0,-1*buff_range)):
		return true
	elif static_body.test_move(transform.scaled_local(Vector3(.9,.9,.9)), Vector3(buff_range,0,0)):
		return true
	elif static_body.test_move(transform.scaled_local(Vector3(.9,.9,.9)), Vector3(-1*buff_range,0,0)):
		return true
	elif static_body.test_move(transform.scaled_local(Vector3(.9,.9,.9)), Vector3(0,buff_range,0)):
		return true
	else:
		return false

#set snap for building placement
func set_snap(snp):
	snapping = snp
	if snp>1:
		collision_buffer=0.1
	else:
		collision_buffer = 1

#pass press to signal activate signal
func _on_static_body_3d_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
		activated.emit(self)
