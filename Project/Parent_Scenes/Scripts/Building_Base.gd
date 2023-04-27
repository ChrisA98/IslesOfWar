extends Node3D

class_name Building

#Custom signals
signal activated


#REF vars
@onready var world = get_parent()
#Pieces of building
@onready var mesh = $MeshInstance3D
@onready var collision_box = $StaticBody3D/CollisionShape3D
@onready var static_body = get_node("StaticBody3D")
@onready var rally = $RallyPoint
@onready var spawn = $SpawnPoint
#Materials
@onready var invalid_mat = preload("res://Materials/preview_building_invalid.tres")
@onready var valid_mat = preload("res://Materials/preview_building_valid.tres")
@export var height : int = 1 
var type
var actor_owner
var faction
var faction_short_name


#Can be placed
var is_valid
#Cost to build
var cost = {"wood": 0,
"stone": 0,
"riches": 0,
"crystals": 0,
"food": 0}
var pop: int = 0
var pop_mod: int = 0

var snapping = 0

var collision_buffer = 0


func _ready():
	pass


func load_data():	
	var suffix = faction_short_name.substr(0,2)
	var b_mesh = load("res://Models/"+faction_short_name+"/"+type+"_"+suffix+".obj")
	if(b_mesh != null):
		mesh.set_mesh(b_mesh)
	

func init(pos, snap: int, actor: Node):
	position = pos
	mesh.transparency = .55
	mesh.set_surface_override_material(0, valid_mat)
	static_body.set_ray_pickable(false)
	actor_owner = actor
	faction = actor.faction_data.name
	faction_short_name = actor.faction_data.short_name
	
	load_data()
	
	set_snap(snap)


func set_pos(pos):
	position = pos
	
	if snapping > 1:
		position.x = ceil(position.x/snapping)*snapping
		position.z = ceil(position.z/snapping)*snapping
	
	#mesh.transform = mesh.transform.looking_at(mesh.position+$RayCast3D.get_collision_normal().rotated(Vector3(0,0,1),-90), Vector3.UP)
	#position.y -= height*.8
	if check_collision(collision_buffer):
		make_invalid()
	else:
		make_valid()


func place():
	for i in range(mesh.get_surface_override_material_count()):
		mesh.set_surface_override_material(i, null)
	mesh.transparency = 0
	static_body.set_ray_pickable(true)
	static_body.set_collision_layer_value(1,true)
	$RallyPoint.visible = false
	$StaticBody3D/CollisionShape3D2.disabled = true
	#snap_to_ground()


func make_valid():
	if can_afford(actor_owner.resources) == false:
		make_invalid()
		return
	is_valid = true
	for i in range(mesh.get_surface_override_material_count()):
		mesh.set_surface_override_material(i, valid_mat)


func make_invalid():
	is_valid = false
	for i in range(mesh.get_surface_override_material_count()):
		mesh.set_surface_override_material(i, invalid_mat)


func check_collision(buff_range):	
	if static_body.test_move(transform.translated(Vector3(0,3,0)), Vector3(0,3,buff_range),null , 0.001, true):
		return true
	elif static_body.test_move(transform.translated(Vector3(0,3,0)), Vector3(0,3,-1*buff_range),null , 0.001, true):
		return true
	elif static_body.test_move(transform.translated(Vector3(0,3,0)), Vector3(buff_range,3,0),null , 0.001, true):
		return true
	elif static_body.test_move(transform.translated(Vector3(0,3,0)), Vector3(-1*buff_range,3,0),null , 0.001, true):
		return true
	else:
		return false


func adj_cost(resource: String, amt: int):
	cost[resource] += amt


## Set snap for building placement
func set_snap(snp):
	snapping = snp
	if snp>1:
		collision_buffer=0.01
	else:
		collision_buffer = .5


func near_base(buildings) -> bool:
	if buildings == null:
		return false
	for b in buildings:
		if b.position.distance_to(position) < b.radius:
			return true
	return false


#pass press to signal activate signal
func _on_static_body_3d_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
		activated.emit(self)


## Call to see if purchasable
func can_afford(builder_res):
	for res in builder_res:
		if builder_res[res] < cost[res] :
			return false
	return true


func snap_to_ground():
	position.y = $RayCast3D.get_collision_point().y
