extends Node3D

class_name Building

#Custom signals
signal pressed
signal died
signal update_fog
signal fog_radius_changed


#REF vars
@onready var world = get_parent()
#Pieces of building
@onready var mesh = $MeshInstance3D
@onready var collision_box = $StaticBody3D/CollisionShape3D
@onready var static_body = get_node("StaticBody3D")
@onready var det_area = get_node("Detection_Area")
@onready var fog_reg = get_node("Fog_Breaker")
@onready var picker = get_node("StaticBody3D/RayCast3D")
@onready var rally = $RallyPoint
@onready var spawn = $SpawnPoint
@onready var menu
#Materials
@onready var prev_mat = preload("res://Materials/preview_building.tres")
@onready var build_shader

@export var height : int = 1 
var type: String
var display_name : String
var actor_owner
var faction
var faction_short_name


#Can be placed
var is_valid = false
@onready var base_transform = transform
var is_building : bool = false
@export var build_time : float = 10
@onready var build_timer : float = build_time
@onready var build_particles = get_node("GPUParticles3D")
var magic_color : Color
@export var fog_rev_radius : float = 50

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
@export var armor: int = 10
@export var health: float = 0

func _ready():
	build_shader = load("res://Materials/building.gdshader")
	prev_mat = prev_mat.duplicate(true)
	build_shader = build_shader.duplicate(true)
	build_particles.visible = false
	pass


func _physics_process(delta):
	if(is_building):
		build_timer-=delta
		var prog = height*((build_time-build_timer)/build_time)
		build_particles.position.y = prog
		for i in range(mesh.get_surface_override_material_count()):
			mesh.mesh.surface_get_material(i).set_shader_parameter("progress", prog)
		if prog > 1:
			finish_building()
			return

## Initialize certain elements at start
func init(pos, snap: int, actor: Node):
	position = pos
	mesh.transparency = .55
	static_body.set_ray_pickable(false)
	actor_owner = actor
	faction = actor_owner.faction_data.name
	faction_short_name = actor_owner.faction_data.short_name
	
	load_data(actor_owner.faction_data)
	for i in range(mesh.get_surface_override_material_count()):
		mesh.mesh.surface_set_material(i,ShaderMaterial.new())	##Later load materials here
	set_all_over_mats(prev_mat)
	
	set_snap(snap)


func load_data(data):	
	var suffix = faction_short_name.substr(0,2)
	#check for file and load if exists
	if(FileAccess.file_exists ("res://Models/"+faction_short_name+"/"+type+"_"+suffix+".obj")):
		var b_mesh = load("res://Models/"+faction_short_name+"/"+type+"_"+suffix+".obj")
		if(b_mesh != null):
			mesh.set_mesh(b_mesh.duplicate(true))
	else:
		mesh.set_mesh(BoxMesh.new())
		print_debug("Building model:"+type+" does not exist")
	for res in cost:
		cost[res] = data.buildings[type].base_cost[res]
	display_name = data.buildings[type]["base_display_name"]
	magic_color = data["magic_color"]


func set_pos(pos):
	transform = base_transform
	position = pos
	align_to_ground()
	position = pos
	snap_to_ground()
	det_area.force_update_transform()
	
	if snapping > 1:
		position.x = ceil(position.x/snapping)*snapping
		position.z = ceil(position.z/snapping)*snapping
	
	
	# Check can afford
	if can_afford(actor_owner.resources) !=null:
		make_invalid()
		return "cant afford"
	
	##check for collisions
	if check_collision(collision_buffer):
		make_invalid()
		return "colliding"	
		
	# Calculate ground normal validity
	if (Vector3.UP.dot(picker.get_collision_normal()) < .93):
		make_invalid()
		return
	
	## Make invalid if locked to base radius
	if(get_meta("show_base_radius")):
		if near_base(actor_owner.bases) == false:
			make_invalid()
			return "out of zone"
	
	## Make sure can be seen
	if !is_visible_area() and type != "Base":
		make_invalid()
		return "cant see"
	
	make_valid()


## Place and start building
func place():
	static_body.set_ray_pickable(true)
	static_body.set_collision_layer_value(1,true)
	$RallyPoint.visible = false
	$StaticBody3D/CollisionShape3D2.disabled = true
	set_all_shader(build_shader)
	set_all_over_mats(null)
	for i in range(mesh.get_surface_override_material_count()):
		mesh.mesh.surface_get_material(i).set_shader_parameter("magic_color", magic_color)
	is_building = true
	build_particles.visible = true
	build_particles.draw_pass_1.surface_get_material(0).albedo_color = magic_color
	fog_reg.fog_break_radius = fog_rev_radius*.5
	if(actor_owner.actor_ID == 0):
		get_parent().added_fog_revealer(self)
		update_fog.emit(self,position)


#Finish the building process
func finish_building():
	is_building = false
	for i in range(mesh.get_surface_override_material_count()):
		mesh.mesh.surface_get_material(i).set_shader_parameter("magic_color", Color.FLORAL_WHITE)
	build_particles.visible = false
	mesh.transparency = 0
	await get_tree().physics_frame
	fog_reg.fog_break_radius = fog_rev_radius
	update_fog.emit(self,position)
	fog_radius_changed.emit(self)


## Can place
func make_valid():
	is_valid = true
	set_mat_over_color(Color.CORNFLOWER_BLUE)


## Cannot place
func make_invalid():
	is_valid = false
	set_mat_over_color(Color.INDIAN_RED)


## Set all surfaces to override material
func set_all_over_mats(mat):
	for i in range(mesh.get_surface_override_material_count()):
		mesh.set_surface_override_material(i, mat)


## Set all surfaces to override material
func set_mat_over_color(col):
	for i in range(mesh.get_surface_override_material_count()):
		mesh.get_surface_override_material(i).albedo_color = col


## sets material to a shader for building
func set_all_shader(shad):
	for i in range(mesh.get_surface_override_material_count()):
		mesh.mesh.surface_get_material(i).set_shader(shad)


## Check for collision at current location
func check_collision(_buff_range):
	for ar in det_area.get_overlapping_areas():
		if !ar.has_meta("is_world_obj") and !ar.has_meta("is_fog_area"):
			return true
	for bod in det_area.get_overlapping_bodies():
		if bod.has_meta("is_ground"):
			return true
	return false


## Check that building is in visible area
func is_visible_area():	
	for ar in fog_reg.detect_area.get_overlapping_areas():
		if(ar.has_meta("fog_owner_id")):
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
	if(is_building):
		return
	if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
		pressed.emit(self)


## Call to see if purchasable
func can_afford(builder_res):
	for res in builder_res:
		if builder_res[res] < cost[res] :
			return res
	return null


func align_to_ground():
	picker.force_raycast_update()
	var norm = picker.get_collision_normal()
	var cosa = Vector3.UP.dot(norm)
	var alph = acos(cosa)
	var axis = Vector3.UP.cross(norm)
	transform = transform.rotated(axis.normalized(),alph)


func snap_to_ground():
	picker.force_raycast_update()
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
