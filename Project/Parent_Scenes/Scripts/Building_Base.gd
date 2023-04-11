extends Node3D

class_name Building

#custom signals
signal activated


#REF vars
@onready var world = get_parent()
#pieces of building
@onready var mesh = $MeshInstance3D
@onready var collision_box = $StaticBody3D/CollisionShape3D
@onready var static_body = $StaticBody3D
@onready var rally = $RallyPoint
@onready var spawn = $SpawnPoint
#materials
@onready var invalid_mat = preload("res://Materials/preview_building_invalid.tres")
@onready var valid_mat = preload("res://Materials/preview_building_valid.tres")
var type
var player_owner


#can be placed
var is_valid
#Cost to build
var cost = {"wood": 0,
"stone": 0,
"riches": 0,
"crystals": 0,
"food": 0}
var pop: int = 0
var pop_mod: int = 0

#is snapping to grid
var snapping = 0


var collision_buffer = 0


func _ready():
	pass


func init(pos, snap: int, player: Node):
	position = pos
	mesh.transparency = .55
	mesh.set_surface_override_material(0, valid_mat)
	static_body.set_ray_pickable(false)
	player_owner = player
	
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
	$RallyPoint.visible = false


func make_valid():
	for res in cost:
		if player_owner.resources[res] < cost[res]:
			make_invalid()
			return
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


func adj_cost(resource: String, amt: int):
	cost[resource] += amt


#set snap for building placement
func set_snap(snp):
	snapping = snp
	if snp>1:
		collision_buffer=0.1
	else:
		collision_buffer = .5


#pass press to signal activate signal
func _on_static_body_3d_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
		activated.emit(self)
