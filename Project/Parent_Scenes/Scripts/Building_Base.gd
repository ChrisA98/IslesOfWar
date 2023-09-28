class_name Building
extends Node3D


''' Signals '''
signal pressed
signal died
signal update_fog
signal fog_radius_changed
signal spawned_unit
signal revealed


''' Export Vars '''
@export var build_time : float = 10
@export var type: String
@export var building_height: float = 1

@export_group("Appearance")
@export var hide_grass : bool = true
@export var fog_rev_radius : float = 50
@export var menu_pages = {"units": "","sec_units": "","research": "","page_4": ""}
@export_flags("Land","Naval","Aerial") var garrison_unit_type
@export_group("Defense")
@export var base_health : float = 0
@export var attack_radius := 0.0
@export var atk_speed = 2
@export var atk_str = 0.
@export_range(0,.99) var base_armor : float = .1


''' Identifying Vars '''
var actor_owner : game_actor
var parent_base:
	set(value):
		if is_building and parent_base.building_child == self:
			parent_base.building_child = null
			value.building_child = self
		parent_base = value
var parent_building : Building
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
			health.hide_override = false
			building_model.visible = true
			hide_from_mouse(false)
			if(is_building):
				$GPUParticles3D.visible = true
			return
		health.hide_override = true
var is_visible : bool:
	set(value):
		if actor_owner.actor_ID == 0:
			is_visible = true
			return
		is_visible = value
		if value:
			revealed.emit()

''' Building Logic Vars '''
var is_valid = false
var is_building : bool = false:
	set(value):
		if value:
			process_functions.push_back(Callable(_build))
			return
		process_functions.erase(Callable(_build))
var can_attack : bool:
	set(value):
		can_attack = value
		fog_reg.detect_area.set_collision_mask_value(3,can_attack)
		if can_attack:
			atk_timer = Timer.new()
			add_child(atk_timer)
			atk_timer.timeout.connect(_attack)
			atk_timer.start(atk_speed)
var atk_timer : Timer
var snapping = 0
var rot = 0
var building_model


#Cost to build
var cost = {"wood": 0,
"stone": 0,
"riches": 0,
"crystals": 0,
"food": 0}
var pop_mod: int = 0
var garrisoned_units := []
var children_buildings := []
var visible_enemies := []
var process_functions := []


''' Unit Spawning Vars '''
var units := {}				#spawnable units
var train_queue := []		#units queued to train
var is_training := false	#building is training
var trained_squad := Squad.new()

''' On-Ready Vars '''
@onready var health = get_node("Health_Bar")
@onready var attack_manager = get_node("Attack_Manager")

@onready var world = get_parent()
## Children references
@onready var mesh = get_node("MeshInstance3D")
@onready var building_model_loader = get_node("BuildingModel")
@onready var collision_box = get_node("StaticBody3D/CollisionShape3D")
@onready var bldg_radius = collision_box.shape.size.x
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
	
	trained_squad.formation_size = 1
	
	fog_reg.set_actor_owner(actor_owner.actor_ID)	
	fog_reg.detect_area.body_entered.connect(_vision_body_entered)
	fog_reg.detect_area.body_exited.connect(_vision_body_exited)
	
	building_model = building_model_loader.load_model()
	
	if (actor_owner.actor_ID == 0):
		discovered = true
	else:
		building_model.visible = false
		discovered = false
		det_area.area_entered.connect(_detection_area_entered)
		det_area.area_exited.connect(_detection_area_exited)
		hide_from_mouse()
	


func _process(delta):
	for c in process_functions:
		c.call(delta)


## Build Building
func _build(delta):
	if !is_instance_valid(parent_base) and parent_building != null:
			return
	if parent_base.building_child != null and parent_base.building_child != self:
		return
	parent_base.building_child = self
	build_timer-=delta
	var prog = ((build_time-build_timer)/build_time)*building_height
	build_particles.position.y = prog
	building_model.set_override_shader_parameter("progress",prog)
	if prog > 1:
		finish_building()
		return


## Update training data
func _train(_delta):
	if(is_training):
		menu.update_train_prog(train_queue[0],trn_timer.get_time_left()/trn_timer.get_wait_time())

'''### Public Methods ###'''
'''-------------------------------------------------------------------------------------'''
''' Initialization Start '''
## Initialize certain elements at start
func init(_pos, snap: int, actor: Node):
	#position = pos
	static_body.set_ray_pickable(false)
	actor_owner = actor
	faction = actor_owner.faction_data.name
	faction_short_name = actor_owner.faction_data.short_name
	
	load_data(actor_owner.faction_data)
	
	if actor_owner.actor_ID == 0:
		is_visible = true
	
	building_model.init(actor_owner.actor_color)
	
	building_model.set_material_override(prev_mat)
	building_model.transparency = .55
	
	set_snap(snap)
	
	parent_base = actor_owner
	
	## Update health and armor values	
	health.init_health(base_health)
	health.init_armor(base_armor)


func load_data(data):	
	magic_color = data["magic_color"]

	## Set Cost
	for res in cost:
		cost[res] = data.buildings[type].base_cost[res]
	display_name = data.buildings[type]["base_display_name"]
	
	# Set base menu data
	menu.set_menu_data(type)
	
	call_deferred("_load_units",data)


func _load_units(data):
	#Load unit list 2 if exists
	if(data.buildings[type].has("unit_list_2")):
		menu.build_sec_unit_list(data.buildings[type]["unit_list_2"],menu_pages["sec_units"])
		#load unit scenes
		for un in data.buildings[type]["unit_list_2"]:
			units[un] = actor_owner.loaded_units[un]
	#Load unit list if exists
	if(data.buildings[type].has("unit_list")):
		menu.build_unit_list(data.buildings[type].unit_list,menu_pages["units"])
		#load unit scenes
		for un in data.buildings[type]["unit_list"]:
			if actor_owner.loaded_units.has(un):
				units[un] = actor_owner.loaded_units[un]
			else:
				units[un] = actor_owner.loaded_units["Infantry"]
		
		menu.push_train_queue.connect(push_train_queue)
		menu.pop_train_queue.connect(pop_train_queue)
	
''' Initialization End '''
'''-------------------------------------------------------------------------------------'''
''' Placing logic Start '''
func set_pos(pos, wait = false):
	if(is_building):
		return
	if snapping > 1:
		pos.x = ceil(pos.x/snapping)*snapping
		pos.z = ceil(pos.z/snapping)*snapping
	
	transform = base_transform
	rotate_y(rot)
	position = pos
	align_to_ground()
	position = pos
	snap_to_ground()
	det_area.force_update_transform()
	
	
	# Check can afford
	if can_afford(actor_owner.resources) !=null:
		make_invalid()
		return "cant afford"
	if(wait):
		await get_tree().physics_frame
	##check for collisions
	if check_collision():
		make_invalid()
		return "colliding"	
		
	# Calculate ground normal validity
	if (Vector3.UP.dot(picker.get_collision_normal()) < .93):
		make_invalid()
		return
	
	## Make invalid if locked to base radius
	if near_base(actor_owner.bases) == false and get_meta("needs_base"):
		make_invalid()
		return "out of zone"
	
	## Make sure can be seen
	if !is_visible_area() and type != "Base":
		make_invalid()
		return "cant see"
	
	## check for water on center
	if in_water():
		make_invalid()
		return "in water"
	
	make_valid()


## Place and start building
func place():
	# Turn on collision
	static_body.set_ray_pickable(true)
	static_body.set_collision_layer_value(1,true)
	# Hide reference pieces
	$RallyPoint.visible = false
	
	var _build_shader = ShaderMaterial.new()
	_build_shader.set_shader(build_shader)
	
	building_model.set_material_override(_build_shader)
	building_model.set_override_shader_parameter("magic_color", magic_color)
	# Start building
	is_building = true
	if(discovered):
		build_particles.visible = true
	build_particles.draw_pass_1.surface_get_material(0).albedo_color = magic_color
	# Activate Fog interactions
	fog_reg.fog_break_radius = fog_rev_radius*.5
	get_parent().added_fog_revealer(self)
	fog_reg.activate_area()
	if(actor_owner.actor_ID == 0):
		fog_reg.active = true
	await get_tree().physics_frame
	update_fog.emit(self, is_visible)
	fog_radius_changed.emit(self)
	
	get_ground_groups()
	
	## Delete collision objects after ground groups found
	for col in static_body.get_children():
		if col != static_body.get_child(0):
			col.queue_free()
	
	## Setup building web
	if parent_base != actor_owner:
		parent_building = parent_base
		for bldg in parent_base.children_buildings:
			if bldg.position.distance_to(position) < parent_building.position.distance_to(position):
				parent_building = bldg
		parent_base.children_buildings.push_back(self)


## Set snap for building placement
func set_snap(snp):
	snapping = snp


## Can place
func make_valid():
	is_valid = true
	building_model.set_override_albedo(Color.CORNFLOWER_BLUE)


## Cannot place
func make_invalid():
	is_valid = false
	building_model.set_override_albedo(Color.INDIAN_RED)


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


func in_water():
	var corners = static_body.find_children("Corner*")
	for c in corners:
		c.force_raycast_update()
		if(picker.get_collider() != null and picker.get_collider().get_groups().size() == 0):
			return false	
	return true


## Check if close to any buildings in buildings
func near_base(buildings) -> bool:
	if buildings == null:
		return false
	for b in buildings:
		if b.position.distance_to(position) < b.radius:
			parent_base = b
			return true
	parent_base = actor_owner
	return false


## Check that building is in visible area
func is_visible_area():	
	for ar in det_area.get_overlapping_areas():
		if(ar.has_meta("fog_owner_id")):
			if(ar.get_meta("fog_owner_id") == actor_owner.actor_ID and ar.get_parent() != det_area.get_parent()):
				return true
	return false


func adj_cost(resource: String, amt: int):
	cost[resource] += amt


func align_to_ground():
	picker.force_raycast_update()
	var norm = picker.get_collision_normal()
	var cosa = Vector3.UP.dot(norm)
	var alph = acos(cosa)
	var axis = Vector3.UP.cross(norm).normalized()
	if(axis.is_normalized()):
		transform = transform.rotated(axis,alph)


func snap_to_ground():
	picker.force_raycast_update()
	position.y = $StaticBody3D/RayCast3D.get_collision_point().y


## Get groups from ground raycasts
func get_ground_groups():
	var corners = static_body.find_children("Corner*")
	for c in corners:
		var t = (c.get_collider().get_parent().get_parent().get_groups())
		if(t.size() == 0):
			continue
		if !get_groups().has(t[0]):
			add_to_group(c.get_collider().get_parent().get_parent().get_groups()[0])	



''' Placing logic End '''
'''-------------------------------------------------------------------------------------'''
''' Building and Fog logic Start '''
#Finish the building process
func finish_building():
	parent_base.building_child = null
	await get_tree().physics_frame
	is_building = false
	build_particles.visible = false
	building_model.transparency = 0
	fog_reg.fog_break_radius = fog_rev_radius
	update_fog.emit(self, true)
	fog_radius_changed.emit(self)	
		
	# Reset to base materials
	building_model.clear_material_override()


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
'''-------------------------------------------------------------------------------------'''
''' Combat Start '''
func damage(amt: float, _type: String):
	health.damage(amt,_type)
	## DIE
	if(health.health <= 0):
		died.emit()
		delayed_delete()
		return true
	return false

## Attack function
func _attack():
	atk_timer.start(atk_speed)
	if visible_enemies.size() < 1:
		return
	var target_enemy = visible_enemies[0]
	# Attack targeting
	if !is_instance_valid(target_enemy):
		return
	
	if (position.distance_to(target_enemy.position) > attack_radius):
		return
	
	
	attack_manager.attack(position, target_enemy, atk_str)


## Add enemies to sight array
func _vision_body_entered(body):
	if body.has_meta("owner_id") and body.get_meta("owner_id") != actor_owner.actor_ID:
		visible_enemies.push_back(body)


## Remove enemies from sight array
func _vision_body_exited(body):
	if visible_enemies.has(body):
		visible_enemies.erase(body)


## Sort by distance to position
func distance_sort(a, b):
	if position.distance_to(a.position) < position.distance_to(b.position):
		return true
	return false
''' Combat End '''
'''-------------------------------------------------------------------------------------'''
''' User Input Start '''
## Pass press to signal activate signal
func _on_static_body_3d_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton:
		pressed.emit(self)
		if(actor_owner.actor_ID == 0 and !is_building):
			show_menu()


## Show buildings menu
func show_menu(state: = true):
	if(is_building):
		## Building is being built
		return
	if is_instance_valid(menu):
		for i in get_tree().get_nodes_in_group("menu_group_1"):
			i.visible = false
		menu.visible = state
		if state and !process_functions.has(Callable(_train)):
			process_functions.push_back(Callable(_train))
		if !state:
			process_functions.erase(Callable(_train))


## Deactivate picking
func hide_from_mouse(state: = true):
	static_body.input_ray_pickable = !state

''' User Input End '''
'''-------------------------------------------------------------------------------------'''
''' Garrison Start '''
## Garrison unit in base
func garrison_unit(unit):
	match garrison_unit_type:
		1,3,5:
			if unit.nav_agent.get_navigation_layer_value(1) == false:
				return
		2,3,6:
			if unit.nav_agent.get_navigation_layer_value(2) == false:
				return
		4,5,6:
			if unit.nav_agent.get_navigation_layer_value(3) == false:
				return
	garrisoned_units.push_back(unit)
	unit.position = position
	unit.ai_mode = "idle_basic"
	unit.visible = false


## Remove certain garrisoned units
func ungarrison_unit(unit, pos):
	garrisoned_units.erase(unit)
	unit.position = spawn.global_position	
	await get_tree().create_timer(.05).timeout
	unit.visible = true
	unit.set_mov_target(rally.global_position+pos) 


## Empty all Garrisoned units
func empty_garrison():
	for i in range(garrisoned_units.size()):
		await get_tree().create_timer(.5).timeout
		var form_pos = actor_owner.formation_pos(garrisoned_units[0],i)
		ungarrison_unit(garrisoned_units[0],form_pos)


''' Garrison End '''
'''-------------------------------------------------------------------------------------'''
''' Destruction Start '''
## Delay delete and remove from lists
func delayed_delete():
	actor_owner.buildings.erase(self)
	
	if is_instance_valid(parent_base) and parent_base.has_meta("show_base_radius"):
		parent_base.children_buildings.erase(self)
	world.world_buildings.erase(self)
	actor_owner.update_pop()
	await get_tree().physics_frame
	queue_free()
	if get_groups().size() < 1:
		return	
	for g in get_groups():
		world.update_navigation(g)


''' Destruction End '''
'''-------------------------------------------------------------------------------------'''
''' Training Start '''
## Place new unit to end of queue
func push_train_queue(unit: String):
	# Check population
	if actor_owner.faction_data["unit_list"][unit]["pop_cost"] + actor_owner.pop >= actor_owner.max_pop:
		menu.unit_queue_edit(-1,unit)
		return "pop"
	# Check then spend resources
	var tres = actor_owner.can_afford_unit(unit)
	if(typeof(tres) == TYPE_STRING):
		menu.unit_queue_edit(-1,unit)
		return tres
	# Spend Resources
	for res in actor_owner.faction_data["unit_list"][unit]["base_cost"]:
		actor_owner.adj_resource(res,actor_owner.faction_data["unit_list"][unit]["base_cost"][res]*-1)
	
	## Add to taining queue
	train_queue.push_back(unit)
	if(trn_timer.is_stopped()):
		trn_timer.start(.5)
		is_training = true
	return "true"


## Remove unit from training queue
## nan is used for finished trainng units to update the queue
## call with specific unit to remove unit from queue
func pop_train_queue(unit: String = ""):
	## Removing unit by button press
	if(train_queue.has(unit)):
		train_queue.remove_at(train_queue.rfind(unit))
		# Un-Spend Resources
		for res in actor_owner.faction_data["unit_list"][unit]["base_cost"]:
			actor_owner.adj_resource(res,actor_owner.faction_data["unit_list"][unit]["base_cost"][res])
		if(train_queue.size()==0):
			trn_timer.stop()
			is_training = false	
			return
		if(!train_queue.has(unit)):
			trn_timer.start(3)
		return
	## pop front when doing training
	var out = train_queue.pop_front()	##delete front of queue and add it to out to be returned
	is_training = !(train_queue.size() == 0)
	if(train_queue.size()>0):		
		trn_timer.start(3)
		return out
	trn_timer.stop()
	is_training = false
	return out


## Spawn unit and validate spawning
##
## unit_override sets a a specific unit to spawn from the owning_actor list
func spawn_unit(unit_override: String):
	if trained_squad == null:
		_generate_squad()
	var new_unit
	if(unit_override == "nan"):
		menu.unit_queue_edit(-1,train_queue[0])
		menu.update_train_prog(train_queue[0],1)
		var u_name = pop_train_queue()
		
		new_unit = actor_owner.spawn_unit(u_name)
		
		new_unit.visible = false
		new_unit.position = spawn.global_position
		await get_tree().create_timer(.05).timeout
		new_unit.visible = true
		trained_squad.push_back(new_unit)
		new_unit.set_mov_target(rally.global_position+trained_squad.get_newest_formation_position())
	else:
		new_unit = actor_owner.spawn_unit(unit_override)
		
		new_unit.position = spawn.global_position
		new_unit.position.y = new_unit.get_ground_depth()
		
		trained_squad.push_back(new_unit)
	
	spawned_unit.emit(self,new_unit)


func _generate_squad():
	trained_squad = Squad.new()
	trained_squad.actor_owner = actor_owner
	trained_squad.formation_size = 1
	
	
	

''' Training End '''
