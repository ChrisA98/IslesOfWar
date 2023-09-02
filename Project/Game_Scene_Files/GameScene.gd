extends Node3D

''' Signals '''
signal nav_ready
signal click_mode_changed(old, new)
signal prep_ready

@export var debug_controller_swap := 0:
	set(value):
		debug_controller_swap = value
		player_controller = game_actors[value]
''' Unit and Building vars '''
## World lists
var world
var loaded_buildings = []
var world_units = []
var travel_queue_units := []
var menu_buildings = {}
var world_buildings = []

## Preview Building Info
var building_snap = 0
var preview_building: Node3D:
	get:
		return preview_building
	set(value):
		preview_building = value
		## Hide build radii
		if(value == null):
			for i in player_controller.bases:
				i.hide_radius()
			return
		#show build radii
		if(preview_building.get_meta("show_base_radius") or preview_building.get_meta("show_base_radius")):
			for i in player_controller.bases:
				i.preview_radius()

''' User input vars '''
var activated_building = null
var selection_square_points = [Vector3.ZERO,Vector3.ZERO]
var click_mode: String = "select":
	get:
		return click_mode
	set(value):
		click_mode_changed.emit(click_mode, value)
		click_mode = value
var mouse_loc_stored

''' onready vars '''
@onready var UI_controller = $UI_Node
@onready var player_controller = $Player
@onready var faction_data = [preload("res://Faction_Resources/Amerulf_Resource.json"),
preload("res://Faction_Resources/Amerulf_Resource.json")]
@onready var game_actors = [$Player]
@onready var global = get_node("/root/Global_Vars")
@onready var player_fog_manager = get_node("Player/SubViewportContainer/Fog_drawer")
@onready var enemy_marker_manager = get_node("UI_Node/Minimap/Enemy_minimap_markers")
@onready var selection_square = get_node("Player/Selection_square")


'''### BUILT-IN METHODS ###'''
#Called when the node enters the scene tree for the first time.
func _ready():
	# Load level
	var lvl = load("res://World_Generation/base_level.tscn").instantiate()
	world = lvl
	add_child(lvl)


#Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	world.sun_rotation = clampf(180-(180*($UI_Node/Time_Bar/Day_Cycle_Timer.time_left/global.DAY_LENGTH)),0,180)
	world.sun.rotation_degrees = Vector3(-world.sun_rotation,90,-180)
	world.sun.light_energy = clampf(world.sun_str - ((world.sun_str * (abs(world.sun_rotation-90)/180))*2), world.sun_str*.15,world.sun_str)
	world.moon_rotation = 180-(180*($UI_Node/Time_Bar/Day_Cycle_Timer.time_left/global.NIGHT_LENGTH))
	world.moon.rotation_degrees = Vector3(-world.moon_rotation,90,-180)
	world.moon.light_energy = world.moon_str - ((world.moon_str * (abs(world.moon_rotation-90)/180))*2) + world.moon_str*.02
	if(world.day_cycle):
		$UI_Node/Time_Bar/Clock_Back.rotation = deg_to_rad(world.sun_rotation-90)
	else:
		$UI_Node/Time_Bar/Clock_Back.rotation = deg_to_rad(world.moon_rotation+90)
	
	##Update world animation time
	RenderingServer.global_shader_parameter_set("game_time",Time.get_ticks_msec()/1000.0)
	


## on player input event
func _input(event):
	if event.is_action_pressed("select_all_units"):
		for u in player_controller.units:
			player_controller.select_unit(u,false,false)
		player_controller.group_selected_units()


'''### PUBLIC METHODS ###'''
func set_map_snap(snp):
	building_snap = snp
	if preview_building != null:
		preview_building.set_snap(snp)


## Update target navmeshes
##
## leave null to update all meshes
func update_navigation(region = null):
	world.update_navigation_meshes(region)


## Connect newly spawned unit to world
func spawn_unit(unit):
	add_child(unit)
	world_units.push_back(unit)
	unit.unit_list = world_units
	unit.selected.connect(unit_selected)
	return true



'''-------------------------------------------------------------------------------------'''
''' Unit Selection Start '''
## Check what unit is being clicked and what to do with it
func unit_selected(unit, event):
	UI_controller.close_menus()
	
	if(unit.actor_owner == player_controller):
		click_mode = "command_unit"
		player_controller.select_unit(unit,! event.is_shift_pressed())
	else:
		if click_mode == "command_unit":
			player_controller.command_unit_attack(unit)


## Remove selected unit from list
func deselect_unit(unit):
	player_controller.deselect_unit(unit)


## Start Selection Square
func start_select_square(pos):
	for i in get_tree().get_nodes_in_group("pickable_object"):
		i.set_ray_pickable(false)
	selection_square_points = [Vector3.ZERO,Vector3.ZERO]
	selection_square.size.x = 1
	selection_square.size.y = 5
	selection_square.size.z = 1
	selection_square.position = pos+Vector3(0.5,0,0.5)
	selection_square_points = [pos, pos]


## Update dimensions and move Selection Square
func update_select_square(pos):
	if (selection_square_points[0] == Vector3.ZERO):
		start_select_square(pos)
		click_mode = "square_selecting"
	if(selection_square.size.x + selection_square.size.z < 4):
		selection_square.visible = false
	else:
		selection_square.visible = true
	selection_square_points[1] = pos
	selection_square.position = selection_square_points[0].lerp(selection_square_points[1], 0.5)
	selection_square.size.x = abs(selection_square_points[1].x - selection_square_points[0].x)
	selection_square.size.y = 20
	selection_square.size.z = abs(selection_square_points[1].z - selection_square_points[0].z)

## Do square selection and add them to selected_units
##
## returns true when box selects something, returns false otherwise
func select_from_square():	
	## unhide pickable objects
	for i in get_tree().get_nodes_in_group("pickable_object"):
		i.set_ray_pickable(true)
	## Update selection square
	selection_square.visible = false
	selection_square_points = [Vector3.ZERO,Vector3.ZERO]
	if(selection_square.size.x + selection_square.size.z < 4):
		if click_mode != "square_selecting":
			return false
		click_mode = "select"
		return false
	selection_square.get_child(0).enabled = true
	selection_square.get_child(0).shape.set_size(Vector3(selection_square.size.x,50,selection_square.size.z))
	selection_square.get_child(0).force_shapecast_update()
	player_controller.clear_selection()
	## Select new units
	for i in selection_square.get_child(0).get_collision_count():
		var un = (selection_square.get_child(0).get_collider(i))
		if un.actor_owner.actor_ID == player_controller.actor_ID:
			player_controller.select_unit(un,false,false)
			un.select()
	selection_square.get_child(0).enabled = false
	if(player_controller.selected_units.size()>0):
		click_mode = "command_unit"
		player_controller.group_selected_units()
	else:
		if click_mode != "square_selecting":
			return true
		click_mode = "select"
	return true


## Select signal from unit list
func select_from_list(units):
	player_controller.clear_selection()
	player_controller.select_group(units)



''' Unit Selection End '''
'''-------------------------------------------------------------------------------------'''
''' Prep Game and world management Start '''
func _prepare_game():
	# Connect ground signals
	for i in world.find_children("Region*"):
		for j in i.find_children("Floor"):
			j.get_child(0).input_event.connect(ground_click)	
	
	# UI Signals
	UI_controller.minimap_clicked.connect(_minimap_Clicked)
	
	# Connect gamescene signals
	click_mode_changed.connect(click_mod_update)
	
	# Generate enemy actors
	var e_script = load("res://Actor_Classes/Enemy.gd")
	for i in range(1,faction_data.size()):
		var e = Node.new()
		e.set_script(e_script)
		e.name = "Enemy_"+str(i)
		e.actor_ID = i
		game_actors.push_back(e)
		add_child(e)
		e.building_added.connect(world.building_added)
	player_controller.building_added.connect(world.building_added)
	
	# Get building buttons UI element ref
	var res_bldgs = get_node("UI_Node/Build_Menu/Build_Menu_Container/Resource_Buttons").get_popup()
	res_bldgs.id_pressed.connect(prep_player_building.bind(res_bldgs))
	var mil_bldgs = get_node("UI_Node/Build_Menu/Build_Menu_Container/Military_Buttons").get_popup()
	mil_bldgs.id_pressed.connect(prep_player_building.bind(mil_bldgs))
	var gen_bldgs = get_node("UI_Node/Build_Menu/Build_Menu_Container/General_Buttons").get_popup()
	gen_bldgs.id_pressed.connect(prep_player_building.bind(gen_bldgs))
	
	# Load building scenes from JSON data
	for fac in range(faction_data.size()):
		loaded_buildings.push_back({})
		game_actors[fac].faction_data = faction_data[fac].data
		game_actors[fac].load_units()
		for b in faction_data[fac].data.buildings:			
			#check for file and load if exists
			if(FileAccess.file_exists ("res://Buildings/"+b+".tscn")):
				loaded_buildings[fac][b] = load("res://Buildings/"+b+".tscn")
			else:
				loaded_buildings[fac][b] = null
				push_warning("Scene file ["+b+".tscn] not found")
			if(fac == player_controller.actor_ID):
				menu_buildings[faction_data[fac]["data"]["buildings"][b].base_display_name] = b
				match faction_data[fac]["data"]["buildings"][b].category:
					"resource":
						res_bldgs.add_item(faction_data[fac]["data"]["buildings"][b].base_display_name)
					"military":
						mil_bldgs.add_item(faction_data[fac]["data"]["buildings"][b].base_display_name)
					"base":
						gen_bldgs.add_item(faction_data[fac]["data"]["buildings"][b].base_display_name)
					_:
						pass
	
	call_deferred("prepare_bases")
	call_deferred("custom_nav_setup")


## Place starting bases
func prepare_bases():
	await get_tree().physics_frame ## fix for collision issue
	# Place enemy starting Bases
	for enemy in range(1,game_actors.size()):
		game_actors[enemy].build_enemy_list()
		var spawn = world.get_base_spawn(enemy)
		var bldg = prep_other_building(game_actors[enemy],"Base")
		bldg.set_pos(spawn.position)
		bldg.set_pos(Vector3(spawn.position.x,game_actors[enemy].ping_ground_depth(bldg.position),spawn.position.z))
		game_actors[enemy].place_building(bldg)
		bldg.spawn_unit(game_actors[enemy].faction_data["starting_unit"])
		spawn.used = true
		
	# Add player first Base
	var p_spawn = world.get_base_spawn(0)
	player_controller.set_cam_pos(p_spawn.position + Vector3(0,20,0))
	player_controller.get_child(0).force_raycast_update()
	prep_player_building(0, null)
	preview_building.set_pos(p_spawn.position)
	player_controller.place_building(preview_building)
	for i in range(400):
		preview_building.spawn_unit(player_controller.faction_data["starting_unit"])
	p_spawn.used = true
	preview_building = null
	click_mode = "select"
	
	await get_tree().physics_frame
	prep_ready.emit()


## Setup navigation
func custom_nav_setup():
	#create navigation map
	var map: RID = NavigationServer3D.map_create()
	NavigationServer3D.map_set_up(map, Vector3.UP)
	NavigationServer3D.map_set_cell_size(map,.35)
	NavigationServer3D.map_set_active(map, true)
	nav_ready.emit()
	NavigationServer3D.map_set_edge_connection_margin(get_world_3d().get_navigation_map(),8)
	update_navigation()


## Recieve signal for navigation updates
func _navmesh_update_start():
	for unit in world_units:
		if unit.ai_mode.contains("travel"):
			var ind = clamp(unit.nav_agent.get_current_navigation_path_index()+15,0,unit.nav_agent.get_current_navigation_path().size()-1)
			if(ind < 0):
				continue
			var pos = unit.nav_agent.get_current_navigation_path()[ind]
			unit.stored_trgt_pos = unit.nav_agent.get_final_position()
			unit.queue_move(pos)
			travel_queue_units.push_back(unit)


## Recieve signal for navigation updates
func _navmesh_updated():
	for unit in travel_queue_units:
		unit.queue_move(unit.stored_trgt_pos)
		unit.stored_trgt_pos = null
	travel_queue_units.clear()


''' Prep Game  and world managementEnd '''
'''-------------------------------------------------------------------------------------'''
''' Building Placement Start '''
##  Prepare new building for player
func prep_player_building(id, menu):
	# Clear existing preview buildings
	if(preview_building != null):
		preview_building.queue_free()
		preview_building = null
	var new_build
	if(menu != null):
		new_build = loaded_buildings[0][menu_buildings[menu.get_item_text(id)]].instantiate(1)
	else:
		new_build = loaded_buildings[0]["Base"].instantiate(1)
	new_build.actor_owner = player_controller
	add_child(new_build)
	new_build.init(position, building_snap, player_controller)
	preview_building = new_build
	
	#reset menu visibility
	UI_controller.close_menu(0)
	click_mode = "build"


##  Prepare new building for other actors
func prep_other_building(actor, bldg_name):
	var new_build = loaded_buildings[actor.actor_ID][bldg_name].instantiate(1)
	new_build.actor_owner = actor
	add_child(new_build)
	new_build.init(position, 0, actor)
	
	return new_build


''' Building Placement End '''
'''-------------------------------------------------------------------------------------'''
''' Player Input Start '''


## Activate buildings menu
func building_pressed(building):
	if Input.is_action_just_released("lmb"):
		if !player_controller.owns_building(building):
			if click_mode == "command_unit":
				player_controller.command_unit_attack(building)
			return
		
		activated_building = building #pass activated building to gamescene
		click_mode = "menu"
	if Input.is_action_just_released("rmb"):
		if !player_controller.owns_building(building):
			return
		match click_mode:
			"command_unit":
				for u in player_controller.selected_units:
					u.set_garrison_target(building)
				player_controller.clear_selection()
			_:
				activated_building = building #pass activated building to gamescene
				click_mode = "menu"
	


## Clicks on world
func ground_click(_camera, event, pos, _normal, _shape_idx, _shape):
	match click_mode:
		"build":
			if(Input.is_action_just_pressed("rmb")):
				mouse_loc_stored = get_viewport().get_mouse_position()
				Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
			if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				preview_building.rotate_y(event.get_relative().x/100)
				preview_building.rot += event.get_relative().x/100
				return
			if(Input.is_action_just_released("rmb")):
				get_viewport().warp_mouse(mouse_loc_stored)
				Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
				return
			if(preview_building != null):
				preview_building.set_pos(pos)
			if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
				if await player_controller.place_building(preview_building):
					#Reset click mode
					click_mode = "select"
					preview_building = null
		"command_unit":
			if Input.is_action_pressed("lmb"):
				selection_square_points = [Vector3.ZERO,Vector3.ZERO]
				update_select_square(pos)
				return
			if Input.is_action_just_released("rmb"):
				player_controller.command_unit_move(pos)
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
				##DEBUG tool to teleport units
				for i in player_controller.selected_units:
					i.position = pos + Vector3.UP
		"select":
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
					click_mode = "select"
					return
			if Input.is_action_pressed("lmb"):
				selection_square_points = [Vector3.ZERO,Vector3.ZERO]
				update_select_square(pos)
				return
		"square_selecting":
			if Input.is_action_pressed("lmb"):
				update_select_square(pos)
				return
			if Input.is_action_just_released("lmb"):
				select_from_square()
		"menu":
			if event is InputEventMouseButton:
				if event.pressed:
					click_mode = "select"
					return
		_:
			pass


## Button pressed on unit menu (CHANGE THIS)
func _on_unit_test_button_pressed():
	activated_building.use("base")


## Clear preview building when menu opened
func _on_ui_node_menu_opened():
	if(preview_building != null):
		preview_building.queue_free()
		preview_building = null
	click_mode = "menu"


## Signal when updating click mode
func click_mod_update(old, new):
	var t = [old,new]
	if(new != "menu"):
		UI_controller.close_menus()
		for b in player_controller.buildings:
			b.show_menu(false)
	match t:
		["command_unit", _]:
			player_controller.clear_selection()
		[_, "command_unit"]:
			## Maybe can remove this line later
			for u in player_controller.units:
				if !player_controller.selected_units.has(u):
					u.select(false)
			UI_controller.set_unit_list()
		["build", _]:
			if(preview_building != null and new != "select"):
				preview_building.queue_free()
				preview_building = null


## Minimap clicked signal recieved
func _minimap_Clicked(command : String, pos : Vector2):
	var world_pos = Vector3()
	world_pos.x = pos.x
	world_pos.y = world.heightmap.get_pixel(int(pos.x)+500,int(pos.y)+500).r*world.terrain_amplitude + player_controller.cam.zoom
	world_pos.z = pos.y 
	match command:
		"move_cam":
			player_controller.cam.position = world_pos
		"ping":
			match click_mode:
				"command_unit":
					player_controller.command_unit_move(world_pos)


''' Player Input End '''
'''-------------------------------------------------------------------------------------'''
## Day/Night Cycle
func _on_day_cycle_timer_timeout():
	for f in game_actors:
		f.adj_resource("food", f.units.size()* -1)
	
	if(world.day_cycle):
		world.sun.visible = false
		world.moon.visible = true
		world.moon.rotation_degrees = Vector3(0,90,-180)
		world.moon_rotation = 0
	else:
		world.year_day+=1
		world.sun.visible = true
		world.moon.visible = false
		world.sun.rotation_degrees = Vector3(0,90,-180)
		world.sun_rotation = 0
	
	world.day_cycle = !world.day_cycle
		
	if world.year_day >= global.YEAR_LENGTH:
		world.year_day = 0
		world.year += 1	
	
	UI_controller.update_clock()


## Trigger when entity enters 
func added_fog_revealer(child: Node):
	if child.has_meta("reveals_fog"):
		if(child.actor_owner.actor_ID == player_controller.actor_ID):
			player_fog_manager.create_drawer(child)
		else:
			enemy_marker_manager.create_drawer(child)
