class_name Building
extends Node3D


''' Signals '''
signal pressed
signal died
signal update_fog
signal fog_radius_changed


''' Export Vars '''
@export var height : int = 1 
@export var type: String
@export var menu_pages = {"units": "","sec_units": "","research": "","page_4": ""}
@export var build_time : float = 10
@export var fog_rev_radius : float = 50
# Combat variables
@export var armor: int = 10
@export var health: float = 0


''' Identifying Vars '''
var actor_owner : game_actor
var display_name : String
var faction : String
var faction_short_name : String
var magic_color : Color
var tier: int = 0

var base_mats = [] ## Stores base materials
var discovered : bool:
	set(value):
		discovered = value
		if value:
			$MeshInstance3D.visible = true
			hide_from_mouse(false)
var is_visible : bool:
	set(value):
		is_visible = value
		$MeshInstance3D/Hiding.visible = true

''' Building Logic Vars '''
var is_valid = false
var is_building : bool = false
var snapping = 0
#Cost to build
var cost = {"wood": 0,
"stone": 0,
"riches": 0,
"crystals": 0,
"food": 0}
var pop_mod: int = 0


''' Unit Spawning Vars '''
var units := {}				#spawnable units
var train_queue := []		#units queued to train
var is_training := false	#building is training

''' On-Ready Vars '''
@onready var world = get_parent()
## Children references
@onready var mesh = get_node("MeshInstance3D")
@onready var collision_box = get_node("StaticBody3D/CollisionShape3D")
@onready var static_body = get_node("StaticBody3D")
@onready var det_area = get_node("Detection_Area")
@onready var fog_reg = get_node("Fog_Breaker")
@onready var picker = get_node("StaticBody3D/RayCast3D")
@onready var rally = get_node("RallyPoint")
@onready var spawn = get_node("SpawnPoint")
@onready var menu = get_node("Menu")
@onready var trn_timer = get_node("Train_Timer")
## Materials vars
@onready var prev_mat = preload("res://Materials/preview_building.tres")
@onready var build_shader = preload("res://Materials/building.gdshader")
## Building vars
@onready var base_transform = transform
@onready var build_timer : float = build_time
@onready var build_particles = get_node("GPUParticles3D")


'''### Built-In Methods ###'''
func _ready():
	prev_mat = prev_mat.duplicate(true)
	build_shader = build_shader.duplicate(true)
	build_particles.visible = false
	position = Vector3(0,-100,0)
	fog_reg.set_actor_owner(actor_owner.actor_ID)
	if (actor_owner.actor_ID == 0):
		discovered = true
	else:
		$MeshInstance3D.visible = true
		discovered = false
		det_area.area_entered.connect(_detection_area_entered)
		det_area.area_exited.connect(_detection_area_exited)
		hide_from_mouse()


func _process(delta):
	if(is_building):
		build_timer-=delta
		var prog = height*((build_time-build_timer)/build_time)
		build_particles.position.y = prog
		for i in range(mesh.get_surface_override_material_count()):
			mesh.mesh.surface_get_material(i).set_shader_parameter("progress", prog)
		if prog > 1:
			finish_building()
			return
	if(is_training):
		menu.update_train_prog(train_queue[0],trn_timer.get_time_left()/trn_timer.get_wait_time())

'''### Public Methods ###'''

''' Initialization Start '''
## Initialize certain elements at start
func init(_pos, snap: int, actor: Node):
	#position = pos
	mesh.transparency = .55
	static_body.set_ray_pickable(false)
	actor_owner = actor
	faction = actor_owner.faction_data.name
	faction_short_name = actor_owner.faction_data.short_name
	
	load_data(actor_owner.faction_data)	
	# Populate base materials
	for i in range(mesh.get_surface_override_material_count()):
		base_mats.push_back(mesh.mesh.surface_get_material(i))

	for i in range(mesh.get_surface_override_material_count()):
		mesh.mesh.surface_set_material(i,ShaderMaterial.new())	##Later load materials here
	set_all_over_mats(prev_mat)
	
	set_snap(snap)


func load_data(data):	
	magic_color = data["magic_color"]
	var suffix = faction_short_name.substr(0,2)
	# Check for mesh file and load if exists
	if(FileAccess.file_exists("res://Models/"+faction_short_name+"/"+type+"_"+suffix+".obj")):
		var b_mesh = load("res://Models/"+faction_short_name+"/"+type+"_"+suffix+".obj")
		if(b_mesh != null):
			mesh.set_mesh(b_mesh.duplicate(true))
		if(type == "Barracks"):
			for s in range(mesh.mesh.get_surface_count()):
				if(mesh.mesh.surface_get_name(s) == "Roof"):
					mesh.mesh.surface_get_material(s).set_albedo(magic_color)
	else:
		mesh.set_mesh(BoxMesh.new())
		print_debug("Building model:"+type+" does not exist")
	## Set Cost
	for res in cost:
		cost[res] = data.buildings[type].base_cost[res]
	display_name = data.buildings[type]["base_display_name"]
	
	# Set base menu data
	menu.set_menu_data(type)
	
	#Load unit list if exists
	if(data.buildings[type].has("unit_list")):
		menu.set_unit_list_main(data.buildings[type].unit_list,menu_pages["units"])
		actor_owner.loaded_units["Infantry"] = load("res://Units/Infantry.tscn")
		units["Infantry"] = actor_owner.loaded_units["Infantry"]
		#load unit scenes
		for un in data.buildings[type]["unit_list"]:
			units[un] = actor_owner.loaded_units[un]
		menu.push_train_queue.connect(push_train_queue)
		menu.pop_train_queue.connect(pop_train_queue)

''' Initialization End '''

''' Placing logic Start '''
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
	if check_collision():
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
	# Turn on collision
	static_body.set_ray_pickable(true)
	static_body.set_collision_layer_value(1,true)
	# Hide reference pieces
	$RallyPoint.visible = false
	$StaticBody3D/CollisionShape3D2.disabled = true
	set_all_shader(build_shader)
	set_all_over_mats(null)
	for i in range(mesh.get_surface_override_material_count()):
		mesh.mesh.surface_get_material(i).set_shader_parameter("magic_color", magic_color)
	# Start building
	is_building = true
	build_particles.visible = true
	build_particles.draw_pass_1.surface_get_material(0).albedo_color = magic_color
	# Activate Fog interactions
	fog_reg.fog_break_radius = fog_rev_radius*.5
	get_parent().added_fog_revealer(self)
	fog_reg.activate_area()
	update_fog.emit(self,position)
	if(actor_owner.actor_ID == 0):
		fog_reg.active = true


## Set snap for building placement
func set_snap(snp):
	snapping = snp


## Can place
func make_valid():
	is_valid = true
	set_mat_over_color(Color.CORNFLOWER_BLUE)


## Cannot place
func make_invalid():
	is_valid = false
	set_mat_over_color(Color.INDIAN_RED)


## Call to see if purchasable
func can_afford(builder_res):
	for res in builder_res:
		if builder_res[res] < cost[res] :
			return res
	return null


## Check for collision at current location
func check_collision():
	for ar in det_area.get_overlapping_areas():
		if !ar.has_meta("is_world_obj") and !ar.has_meta("is_fog_area"):
			return true
	for bod in det_area.get_overlapping_bodies():
		if bod.has_meta("is_ground"):
			return true
	return false


## Check if close to any buildings in buildings
func near_base(buildings) -> bool:
	if buildings == null:
		return false
	for b in buildings:
		if b.position.distance_to(position) < b.radius:
			return true
	return false


## Check that building is in visible area
func is_visible_area():	
	for ar in det_area.get_overlapping_areas():
		if(ar.has_meta("fog_owner_id")):
			return true
	return false


func adj_cost(resource: String, amt: int):
	cost[resource] += amt


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

''' Placing logic End '''

''' Building and Fog logic Start '''
#Finish the building process
func finish_building():
	await get_tree().physics_frame
	is_building = false
	build_particles.visible = false
	mesh.transparency = 0
	fog_reg.fog_break_radius = fog_rev_radius
	update_fog.emit(self,position)
	fog_radius_changed.emit(self)	
		
	# Reset to base materials
	for i in range(mesh.get_surface_override_material_count()):
		mesh.mesh.surface_set_material(i,base_mats[i])


func _detection_area_entered(area):
	if(area.has_meta("fog_owner_id")):
		if (area.get_meta("fog_owner_id") == 0):
			discovered = true
			is_visible = true


func _detection_area_exited(area):
	if(area.has_meta("fog_owner_id")):
		if (area.get_meta("fog_owner_id") == 0):
			is_visible = false
''' Building logic End '''

''' Material Setting Start '''
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

''' Material Setting End '''

''' Combat Start '''
func damage(amt: float, _type: String):
	health -= amt-armor
	## DIE
	if(health <= 0):
		died.emit()
		delayed_delete()
		return true
	return false

''' Combat End '''

''' User Input Start '''
## Pass press to signal activate signal
func _on_static_body_3d_input_event(_camera, event, _position, _normal, _shape_idx):
	if(is_building):
		## Building is being built
		return
	if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
		pressed.emit(self)
		if(actor_owner.actor_ID == 0):
			show_menu()


## Show buildings menu
func show_menu(state: = true):
	if is_instance_valid(menu):
		menu.visible = state


## Dactivate picking
func hide_from_mouse(state: = true):
	static_body.input_ray_pickable = !state

''' User Input End '''

''' Destruction Start '''
## Delay delete and remove from lists
func delayed_delete():
	actor_owner.buildings.erase(self)
	world.world_buildings.erase(self)
	actor_owner.update_pop()
	await get_tree().physics_frame
	queue_free()
	world.update_navigation(get_groups()[0])

''' Destruction End '''

''' Training Start '''
## Place new unit to end of queue
func push_train_queue(unit: String):
	# Check population
	if actor_owner.faction_data.buildings[type]["unit_list"][unit]["pop_cost"] + actor_owner.pop >= actor_owner.max_pop:
		menu.unit_queue_edit(-1,unit)
		return "pop"
	#check then spend resources
	var tres = actor_owner.can_afford_unit(unit,type)
	if(typeof(tres) == TYPE_STRING):
		menu.unit_queue_edit(-1,unit)
		return tres
	# Spend Resources
	for res in actor_owner.faction_data.buildings[type]["unit_list"][unit]["base_cost"]:
		actor_owner.adj_resource(res,actor_owner.faction_data.buildings[type]["unit_list"][unit]["base_cost"][res]*-1)
	
	## Add to taining queue
	train_queue.push_back(unit)
	if(trn_timer.is_stopped()):
		trn_timer.start(3)
		is_training = true
	return "true"


## Remove unit from training queue
func pop_train_queue(unit: String = ""):
	## Removing unit by button press
	if(train_queue.has(unit)):
		train_queue.remove_at(train_queue.rfind(unit))
		# Un-Spend Resources
		for res in actor_owner.faction_data.buildings[type]["unit_list"][unit]["base_cost"]:
			actor_owner.adj_resource(res,actor_owner.faction_data.buildings[type]["unit_list"][unit]["base_cost"][res])
		if(train_queue.size()==0):
			trn_timer.stop()
			is_training = false	
			return
		if(!train_queue.has(unit)):
			trn_timer.start(3)
		return
	## pop front when doing training
	train_queue.pop_front()	##delete front of queue
	is_training = !(train_queue.size() == 0)
	if(train_queue.size()>0):		
		trn_timer.start(3)
		return
	trn_timer.stop()
	is_training = false


## Spawn unit and validate spawning
##
## unit_override sets a a specific unit to spawn from the owning_actor list
func spawn_unit(unit_override: String):
	var new_unit
	if(unit_override == "nan"):
		menu.unit_queue_edit(-1,train_queue[0])
		menu.update_train_prog(train_queue[0],1)
		pop_train_queue()
		new_unit = units["Infantry"].instantiate()
		world.spawn_unit(actor_owner, new_unit)
		new_unit.position = spawn.global_position
		new_unit.set_mov_target(rally.global_position)
	else:
		new_unit = actor_owner.loaded_units["Infantry"].instantiate()
		world.spawn_unit(actor_owner, new_unit)
		new_unit.position = spawn.global_position
		new_unit.position.y = new_unit.get_ground_depth()

''' Training End '''
