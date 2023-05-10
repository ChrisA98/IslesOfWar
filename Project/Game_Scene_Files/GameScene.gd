extends Node3D

#ref vars
@onready var UI_controller = $UI_Node
@onready var world = $World
@onready var player_controller = $Player
@onready var faction_data = [preload("res://Faction_Resources/Amerulf_Resource.json"),
preload("res://Faction_Resources/Amerulf_Resource.json")]
@onready var game_actors = [$Player]
@onready var global = get_node("/root/Global_Vars")
var loaded_buildings = []
var world_units = []

var menu_buildings = []
var world_buildings = []

var rng = RandomNumberGenerator.new()

#Game logic vars
var building_snap = 0
var preview_building: Node3D
var click_mode: String = "select":
	get:
		return click_mode
	set(value):
		click_mode_changed.emit(click_mode, value)
		click_mode = value
var activated_building = null
var selected_units = []
@onready var selection_square = get_node("Player/Selection_square")
var selection_square_points = [Vector3.ZERO,Vector3.ZERO]

#time keeping
var year_day = 330
var year = 545
var day_cycle = true

##Signals
signal nav_ready
signal click_mode_changed(old, new)


###BUILT IN FUNCTIONS###
#Called when the node enters the scene tree for the first time.
func _ready():
	# Connect ground signals
	for i in world.find_children("Region*"):
		for j in i.find_children("Floor"):
			j.get_child(0).input_event.connect(ground_click)
	
	# Set Sun and moon in place
	$Sun.rotation_degrees = Vector3(0,90,-180)
	$Moon.rotation_degrees = Vector3(0,90,-180)
	
	# Connect player signals
	player_controller.res_changed.connect(set_resource)
	player_controller.pop_changed.connect(set_pop)
	
	# Connect gamescene signals
	click_mode_changed.connect(click_mod_update)
	
	# Generate enemy actors
	var e_script = load("res://Actor_Classes/Enemy.gd")
	for i in range(1,faction_data.size()):
		var e = Node.new()
		e.set_script(e_script)
		e.name = "Enemy_"+str(i)
		e.actor_ID = i
		add_child(e)
		game_actors.push_back(e)
	
	# Get building buttons UI element ref
	menu_buildings = get_node("UI_Node/Build_Menu/Building_Buttons").get_popup()
	menu_buildings.id_pressed.connect(prep_player_building)
	
	# Load building scenes from JSON data
	for fac in range(faction_data.size()):
		loaded_buildings.push_back({})
		game_actors[fac].faction_data = faction_data[fac].data
		for b in faction_data[fac].data.buildings:
			loaded_buildings[fac][b] = load("res://Buildings/"+b+".tscn")
			if(fac == 0):
				menu_buildings.add_item(b)
	
	
	call_deferred("prepare_bases")
	call_deferred("custom_nav_setup")


## Place starting bases
func prepare_bases():
	await get_tree().physics_frame ## fix for collision issue
	# Place enemy starting Bases
	for enemy in range(1,game_actors.size()):
		var spawn = get_node("World/Enemy"+str(enemy)+"_Base_Spawn")
		var bldg = prep_other_building(game_actors[enemy],"Base")
		var grp = game_actors[enemy].ping_ground(bldg.position).get_parent().get_groups()[0]
		bldg.set_pos(spawn.position)
		while bldg.is_valid == false:
			bldg.set_pos(spawn.position)
			spawn.position += Vector3(0,1,0)
		game_actors[enemy].place_building(grp, bldg)
		
	# Add player first Base
	var p_spawn = get_node("World/Player_Base_Spawn")
	player_controller.set_cam_pos(p_spawn.position + Vector3(0,20,0))
	player_controller.get_child(0).get_child(1).force_raycast_update()
	# inelegent solution, but it works
	var grp = player_controller.get_child(0).get_child(1).get_collider().get_parent().get_groups()[0]
	prep_player_building(0)
	preview_building.set_pos(p_spawn.position)
	player_controller.place_building(grp, preview_building)
	preview_building = null
	click_mode = "select"


#Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	$Sun.rotation_degrees -= Vector3((180/(global.DAY_LENGTH))*1.33*delta,0,0)
	$Moon.rotation_degrees -= Vector3((180/(global.NIGHT_LENGTH))*1.31*delta,0,0)


## on player input event
func _input(event):
	if event.is_action_pressed("select_all_units"):
		for u in player_controller.units:
			selected_units.push_back(u)

###GAME FUNCTIONS###
func set_map_snap(snp):
	building_snap = snp
	if preview_building != null:
		preview_building.set_snap(snp)


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


## Update target navmeshes
##
## leave null to update all meshes
func update_navigation(region = null):
	world.update_navigation_meshes(region)


## Spawn unit with ownership assigned to o_player
func spawn_unit(o_player, unit) -> bool:
	# Check pop
	if unit.pop_cost + o_player.pop >= o_player.max_pop:
		return false
	# Check cost
	for res in unit.res_cost:
		if o_player.resources[res] - unit.res_cost[res] < 0:
			return false
	# Spend Resources
	for res in unit.res_cost:
		o_player.adj_resource(res,unit.res_cost[res]*-1)
		
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
	NavigationServer3D.map_set_edge_connection_margin(get_world_3d().get_navigation_map(),3)
	update_navigation()


## Set player resource on screen
func set_resource(resource: String, value: int):
	UI_controller.res_displays[resource].clear()
	UI_controller.res_displays[resource].add_text(var_to_str(value))


## Set player population on screen
func set_pop(current: int, max_pop: int):
	UI_controller.res_displays["pop"].clear()
	UI_controller.res_displays["pop"].add_text(var_to_str(current)+" / " + var_to_str(max_pop))


###SIGNALS FUNCTIONS###

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
			for i in selected_units:
				i.target_enemy = unit
			selected_units[0].set_mov_target(unit.position)
			if(selected_units.size() > 1):
				for j in range(1,selected_units.size()):
					selected_units[0].add_following(selected_units[j])


## Start Selection Square
func start_select_square(pos):
	selection_square.size.x = 1
	selection_square.size.y = 5
	selection_square.size.z = 1
	selection_square.position = pos+Vector3(0.5,0,0.5)
	selection_square_points = [pos, pos]


## update dimesnions and move Selection Square
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
	selection_square_points.sort()
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


##  Prepare new building for player
func prep_player_building(id):	
	# Clear existing preview buildings
	if(preview_building != null):
		preview_building.queue_free()
		preview_building = null
	
	var new_build = loaded_buildings[0][menu_buildings.get_item_text(id)].instantiate()
	add_child(new_build)
	new_build.init(position, building_snap, player_controller)
	preview_building = new_build
		
	if(preview_building.name != "Base"):
		for i in player_controller.bases:
			i.preview_radius()
			
	#reset menu visibility
	UI_controller.close_menu(0)
	click_mode = "build"


##  Prepare new building for other actors
func prep_other_building(actor, bldg_name):
	var new_build = loaded_buildings[actor.actor_ID][bldg_name].instantiate()
	add_child(new_build)
	new_build.init(position, building_snap, actor)
	
	return new_build


## Activate buildings menu
func building_pressed(building):
	if !player_controller.owns_building(building):
		if click_mode == "command_unit":
			for i in selected_units:
				i.target_enemy = building
			selected_units[0].set_mov_target(building.position)
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
			building.show_menu()
		_:
			pass


## Clicks on world
func ground_click(_camera, event, pos, _normal, _shape_idx, shape):
	#print(pos)
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


## Say/Night Cycle
func _on_day_cycle_timer_timeout():
	for f in game_actors:
		f.adj_resource("food", f.units.size()* -1)
	
	if(day_cycle):
		print("is night")
		$Sun.visible = false
		$Moon.visible = true
		print($Sun.rotation_degrees)
	else:
		print("is day")
		print($Sun.rotation_degrees)
		year_day+=1
		$Sun.visible = true
		$Moon.visible = false
		$Sun.rotation_degrees = Vector3(0,90,-180)
		$Moon.rotation_degrees = Vector3(0,90,-180)
		print($Sun.rotation_degrees)
		
	
	if year_day >= global.YEAR_LENGTH:
		year_day = 0
		year += 1


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

