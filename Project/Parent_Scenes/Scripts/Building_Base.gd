extends Node3D

class_name Building

#Custom signals
signal pressed
signal died


#REF vars
@onready var world = get_parent()
#Pieces of building
@onready var mesh = $MeshInstance3D
@onready var collision_box = $StaticBody3D/CollisionShape3D
@onready var static_body = get_node("StaticBody3D")
@onready var det_area = get_node("Detection_Area")
@onready var rally = $RallyPoint
@onready var spawn = $SpawnPoint
@onready var menu
#Materials
@onready var invalid_mat = preload("res://Materials/preview_building_invalid.tres")
@onready var valid_mat = preload("res://Materials/preview_building_valid.tres")

@export var height : int = 1 
var type: String
var display_name : String
var actor_owner
var faction
var faction_short_name


#Can be placed
var is_valid = false
#Cost to build
var cost = {"wood": 0,
"stone": 0,
"riches": 0,
"crystals": 0,
"food": 0}
var pop: int = 0
var pop_mod: int = 0
var tier: int = 0

var snapping = 0
var collision_buffer = 0

# Combat variables
var armor: int = 10
var health: float = 0

func _ready():
	pass


## Initialize certain elements at start
func init(pos, snap: int, actor: Node):
	position = pos
	mesh.transparency = .55
	mesh.set_surface_override_material(0, valid_mat)
	static_body.set_ray_pickable(false)
	actor_owner = actor
	faction = actor_owner.faction_data.name
	faction_short_name = actor_owner.faction_data.short_name
	
	load_data(actor_owner.faction_data)
	
	set_snap(snap)


func load_data(data):	
	var suffix = faction_short_name.substr(0,2)
	var b_mesh = load("res://Models/"+faction_short_name+"/"+type+"_"+suffix+".obj")
	if(b_mesh != null):
		mesh.set_mesh(b_mesh)
	for res in cost:
		cost[res] = data.buildings[type].base_cost[res]
	display_name = data.buildings[type]["base_display_name"]


func set_pos(pos):
	position = pos
	
	if snapping > 1:
		position.x = ceil(position.x/snapping)*snapping
		position.z = ceil(position.z/snapping)*snapping
	
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
	snap_to_ground()


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

## Check for collision at current location
func check_collision(buff_range):
	for ar in det_area.get_overlapping_areas():
		if !ar.has_meta("is_world_obj"):
			return true
	for bod in det_area.get_overlapping_bodies():
		if bod.has_meta("is_ground"):
			return true
	return false


func adj_cost(resource: String, amt: int):
	cost[resource] += amt


func damage(amt: float, _type: String):
	health -= amt-armor
	## DIE
	if(health <= 0):
		died.emit()
		delayed_delete()
		return true
	return false


## Set snap for building placement
func set_snap(snp):
	snapping = snp
	if snp>1:
		collision_buffer=0.01
	else:
		collision_buffer = .5


## Check if close to any buildings in buildings
func near_base(buildings) -> bool:
	if buildings == null:
		return false
	for b in buildings:
		if b.position.distance_to(position) < b.radius:
			return true
	return false


## Pass press to signal activate signal
func _on_static_body_3d_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
		pressed.emit(self)


## Call to see if purchasable
func can_afford(builder_res):
	for res in builder_res:
		if builder_res[res] < cost[res] :
			return res
	return null


func snap_to_ground():
	$StaticBody3D/RayCast3D.force_raycast_update()
	position.y = $StaticBody3D/RayCast3D.get_collision_point().y


## Delay delete and remove from lists
func delayed_delete():
	actor_owner.buildings.erase(self)
	world.world_buildings.erase(self)
	actor_owner.update_pop()
	await get_tree().physics_frame
	queue_free()
	world.update_navigation(get_groups()[0])


#Show buildings menu
func show_menu(state: = true):
	if is_instance_valid(menu):
		menu.visible = state


func hide_from_mouse(state: = true):
	static_body.input_ray_pickable = !state
