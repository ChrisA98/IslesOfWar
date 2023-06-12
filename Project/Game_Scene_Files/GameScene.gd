extends Node3D

''' Signals '''
signal nav_ready
signal click_mode_changed(old, new)


''' Unit and Building vars '''
## World lists
var loaded_buildings = []
var world_units = []
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
var selected_units = []
var selection_square_points = [Vector3.ZERO,Vector3.ZERO]
var click_mode: String = "select":
	get:
		return click_mode
	set(value):
		click_mode_changed.emit(click_mode, value)
		click_mode = value

''' Time keeping vars '''
var year_day = 270
var year = 603
var day_cycle = true
var sun_rotation = 0
var moon_rotation = 0
var sun_str = 1.3
var moon_str = .427

''' onready vars '''
@onready var UI_controller = $UI_Node
@onready var world = $World
@onready var player_controller = $Player
@onready var faction_data = [preload("res://Faction_Resources/Amerulf_Resource.json"),
preload("res://Faction_Resources/Amerulf_Resource.json")]
@onready var game_actors = [$Player]
@onready var global = get_node("/root/Global_Vars")
@onready var player_fog_manager = get_node("Player/Fog_drawer")
@onready var enemy_marker_manager = get_node("UI_Node/Minimap/Enemy_minimap_markers")
@onready var selection_square = get_node("Player/Selection_square")


'''### BUILT-IN METHODS ###'''
#Called when the node enters the scene tree for the first time.
func _ready():
	# Connect ground signals
	for i in world.find_children("Region*"):
		for j in i.find_children("Floor"):
			j.get_child(0).input_event.connect(ground_click)
	
	# Set Sun and moon in place
	$Sun.rotation_degrees = Vector3(0,90,-180)
	$Moon.rotation_degrees = Vector3(0,90,-180)
	
	
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
				print_debug("Scene file: "+b+" does not exist")
			if(fac == 0):
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


#Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	sun_rotation = clampf(180-(180*($UI_Node/Time_Bar/Day_Cycle_Timer.time_left/global.DAY_LENGTH)),0,180)
	$Sun.rotation_degrees = Vector3(-sun_rotation,90,-180)
	$Sun.light_energy = clampf(sun_str - ((sun_str * (abs(sun_rotation-90)/180))*2), sun_str*.15,sun_str)
	moon_rotation = 180-(180*($UI_Node/Time_Bar/Day_Cycle_Timer.time_left/global.NIGHT_LENGTH))
	$Moon.rotation_degrees = Vector3(-moon_rotation,90,-180)
	$Moon.light_energy = moon_str - ((moon_str * (abs(moon_rotation-90)/180))*2) + moon_str*.02
	if(day_cycle):
		$UI_Node/Time_Bar/Clock_Back.rotation = deg_to_rad(sun_rotation-90)
	else:
		$UI_Node/Time_Bar/Clock_Back.rotation = deg_to_rad(moon_rotation+90)


## on player input event
func _input(event):
	if event.is_action_pressed("select_all_units"):
		for u in player_controller.units:
			selected_units.push_back(u)


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


## Spawn unit with ownership assigned to o_player
func spawn_unit(o_player, unit):
	unit.actor_owner = o_player
	add_child(unit)
	o_player.units.push_back(unit)
	world_units.push_back(unit)
	unit.unit_list = world_units
	unit.selected.connect(unit_selected)
	o_player.update_pop()
	return true


## Setup navigation
func custom_nav_setup():
	#create navigation map
	var map: RID = NavigationServer3D.map_create()
	NavigationServer3D.map_set_up(map, Vector3.UP)
	NavigationServer3D.map_set_active(map, true)
	nav_ready.emit()
	NavigationServer3D.map_set_edge_connection_margin(get_world_3d().get_navigation_map(),2)
	update_navigation()


''' Unit Selection Start '''
## Check what unit is being clicked and what to do with it
func unit_selected(unit, event):
	UI_controller.close_menus()
	
	if(unit.actor_owner == player_controller):
		click_mode = "command_unit"
		unit.select()
		if event.is_shift_pressed():
			selected_units.push_back(unit)
		else:
			selected_units = [unit]		
		group_selected_units()
	else:
		if click_mode == "command_unit":
			selected_units[0].declare_enemy(unit)
			if(selected_units.size() > 1):
				for j in range(1,selected_units.size()):
					selected_units[0].add_following(selected_units[j])


## Start Selection Square
func start_select_square(pos):
	selection_square_points = [Vector3.ZERO,Vector3.ZERO]
	selection_square.size.x = 1
	selection_square.size.y = 5
	selection_square.size.z = 1
	selection_square.position = pos+Vector3(0.5,0,0.5)
	selection_square_points = [pos, pos]


## update dimensions and move Selection Square
func update_select_square(pos):
	if (selection_square_points[0] == Vector3.ZERO):
		start_select_square(pos)
	if(selection_square.size.x + selection_square.size.z < 4):
		selection_square.visible = false
	else:
		selection_square.visible = true
		click_mode = "square_selecting"
	selection_square_points[1] = pos
	selection_square.position = selection_square_points[0].lerp(selection_square_points[1], 0.5)
	selection_square.size.x = abs(selection_square_points[1].x - selection_square_points[0].x)
	selection_square.size.y = 20
	selection_square.size.z = abs(selection_square_points[1].z - selection_square_points[0].z)

## Do square selection and add them to selected_units
##
## returns true when box selects something, returns false otherwise
func select_from_square():
	selection_square.visible = false
	selection_square_points = [Vector3.ZERO,Vector3.ZERO]
	if(selection_square.size.x + selection_square.size.z < 4):
		if click_mode != "square_selecting":
			return false
		click_mode = "select"
		return false
	selection_square.get_child(0).get_child(0).shape.size = selection_square.size
	selection_square.get_child(0).get_child(0).shape.size.y = 50
	await get_tree().physics_frame
	selected_units.clear()
	for unit in player_controller.units:
		if selection_square.get_child(0).get_overlapping_bodies().has(unit):
			selected_units.push_back(unit)
			unit.select()
	if(selected_units.size()>0):
		click_mode = "command_unit"
		group_selected_units()
	else:
		if click_mode != "square_selecting":
			return true
		click_mode = "select"
	return true


## Select signal from unit list
func select_from_list(units):
	selected_units = units


## Get unit denominations for unit list
func group_selected_units():
	var u = {}
	for i in selected_units:
		if(u.has(i.unit_name)):
			u[i.unit_name].push_back(i)
		else:
			u[i.unit_name] = [i]
	UI_controller.set_unit_list(u)

''' Unit Selection End '''

''' Building Placement Start '''
## Place starting bases
func prepare_bases():
	await get_tree().physics_frame ## fix for collision issue
	# Place enemy starting Bases
	for enemy in range(1,game_actors.size()):
		game_actors[enemy].build_enemy_list()
		var spawn = get_node("World/Enemy"+str(enemy)+"_Base_Spawn")
		var bldg = prep_other_building(game_actors[enemy],"Base")
		bldg.set_pos(spawn.position)
		var grp = game_actors[enemy].ping_ground(bldg.position).get_parent().get_groups()[0]		
		bldg.set_pos(Vector3(spawn.position.x,game_actors[enemy].ping_ground_depth(bldg.position),spawn.position.z))
		game_actors[enemy].place_building(grp, bldg)
		bldg.spawn_unit("Scout")
		
	# Add player first Base
	var p_spawn = get_node("World/Player_Base_Spawn")
	player_controller.set_cam_pos(p_spawn.position + Vector3(0,20,0))
	player_controller.get_child(0).force_raycast_update()
	# inelegent solution, but it works
	var grp = player_controller.get_child(0).get_collider().get_parent().get_groups()[0]
	prep_player_building(0, null)
	preview_building.set_pos(p_spawn.position)
	player_controller.place_building(grp, preview_building)
	preview_building.spawn_unit("Scout")
	preview_building = null
	click_mode = "select"


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


## Places building into world
##
## To be called by actors to ensure it connects to player
func place_building(grp, building):
	if building.is_valid == false:
		return null
	
	#Connect signals
	building.pressed.connect(building_pressed)
	
	#Place building in world
	world_buildings.push_back(building)
	building.place()
	building.add_to_group(grp)
	update_navigation(grp)
	
	return world_buildings[-1]

''' Building Placement End '''

''' Player Input Start '''


## Activate buildings menu
func building_pressed(building):
	if !player_controller.owns_building(building):
		if click_mode == "command_unit":
			selected_units[0].declare_enemy(building)
			if(selected_units.size() > 1):
				for j in range(1,selected_units.size()):
					selected_units[0].add_following(selected_units[j])
		return
	activated_building = building #pass activated building to gamescene
	var type = building.type
	click_mode = "menu"
	match type:
		"Base":
			player_controller.adj_resource("wood",10)
			player_controller.adj_resource("stone",10)
		"Barracks":
			player_controller.adj_resource("riches",10)
			player_controller.adj_resource("crystals",10)
		_:
			pass


## Clicks on world
func ground_click(_camera, event, pos, _normal, _shape_idx, shape):
	match click_mode:
		"build":
			preview_building.set_pos(pos)
			if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
				if player_controller.place_building(shape.get_groups()[0], preview_building):
					#Reset click mode
					click_mode = "select"
					preview_building = null
		"command_unit":
			if Input.is_action_pressed("lmb"):
				update_select_square(pos)
				return
			if Input.is_action_just_released("lmb"):
				if(await select_from_square()):
					##units selected
					return
			if Input.is_action_just_released("rmb"):
				selected_units[0].set_mov_target(pos)
				selected_units[0].target_enemy = null
				if(selected_units.size() > 1):
					for i in range(1,selected_units.size()):
						selected_units[0].add_following(selected_units[i])
						selected_units[1].target_enemy = null
		"select":
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
					click_mode = "select"
					return
			if Input.is_action_pressed("lmb"):
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
			if(new != "command_unit"):
				for u in selected_units:
					u.select(false)
				UI_controller.set_unit_list()
		[_,"square_selecting"]:
			# hide clicking of buildings
			for b in world_buildings:
				b.hide_from_mouse()
		["square_selecting",_]:
			# allow clicking of buildings again
			for b in world_buildings:
				b.hide_from_mouse(false)
		["build", _]:
			if(preview_building != null and new != "select"):
				preview_building.queue_free()
				preview_building = null


## Minimap clicked signal recieved
func _minimap_Clicked(_command : String, pos : Vector2):
	
	player_controller.get_child(1).position.x = pos.x
	player_controller.get_child(1).position.y = world.heightmap.get_pixel(int(pos.x)+500,int(pos.y)+500).r*world.terrain_amplitude + player_controller.cam.zoom
	player_controller.get_child(1).position.z = pos.y

''' Player Input End '''

## Day/Night Cycle
func _on_day_cycle_timer_timeout():
	for f in game_actors:
		f.adj_resource("food", f.units.size()* -1)
	
	if(day_cycle):
		$Sun.visible = false
		$Moon.visible = true
		$Moon.rotation_degrees = Vector3(0,90,-180)
		moon_rotation = 0
	else:
		year_day+=1
		$Sun.visible = true
		$Moon.visible = false
		$Sun.rotation_degrees = Vector3(0,90,-180)
		sun_rotation = 0
	
	day_cycle = !day_cycle
		
	if year_day >= global.YEAR_LENGTH:
		year_day = 0
		year += 1	
	
	UI_controller.update_clock()


## Trigger when entity enters 
func added_fog_revealer(child: Node):
	if child.has_meta("reveals_fog"):
		if(child.actor_owner.actor_ID == 0):
			player_fog_manager.create_drawer(child)
		else:
			enemy_marker_manager.create_drawer(child)
