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
var punits = []

var menu_buildings = []
var world_buildings = []

var rng = RandomNumberGenerator.new()

#Game logic vars
var building_snap = 0
var preview_building: Node3D
var click_mode: String = "select"
var activated_building = null
var selected_units = []

#time keeping
var year_day = 330
var year = 545
var day_cycle = true

##Signals
signal nav_ready


###BUILT IN FUNCTIONS###
#Called when the node enters the scene tree for the first time.
func _ready():
	for i in world.find_children("Region*"):
		for j in i.find_children("Floor"):
			j.get_child(0).input_event.connect(ground_click)
	
	# Connect player signals
	player_controller.res_changed.connect(set_resource)
	player_controller.pop_changed.connect(set_pop)
	
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
	await get_tree().physics_frame ## debug for collision thing
	# Place enemy starting Bases
	for enemy in range(1,game_actors.size()):
		var spawn = get_node("World/Enemy"+str(enemy)+"_Base_Spawn")
		var bldg = prep_other_building(game_actors[enemy],"Base")
		bldg.set_pos(spawn.position)
		while bldg.is_valid == false:
			bldg.set_pos(spawn.position)
			spawn.position += Vector3(0,1,0)
		game_actors[enemy].place_building(spawn.group, bldg)
		
	# Add player first Base
	var p_spawn = get_node("World/Player_Base_Spawn")
	prep_player_building(0)
	preview_building.set_pos(p_spawn.position)
	player_controller.place_building(p_spawn.group, preview_building)
	preview_building = null
	player_controller.set_cam_pos(p_spawn.position + Vector3(0,20,0))
	click_mode = "select"


#Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


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
	building.activated.connect(building_pressed)
	
	#Place building in world
	world_buildings.push_back(building)
	building.place()
	building.add_to_group(grp)
	update_navigation(grp)
	
	return world_buildings[-1]


func update_navigation(region = null):
	world.update_navigation_meshes(region)


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
	unit.unit_list = o_player.units
	unit.selected.connect(unit_selected)
	o_player.update_pop()
	return true


#setup navigation
func custom_nav_setup():
	#create navigation map
	var map: RID = NavigationServer3D.map_create()
	NavigationServer3D.map_set_up(map, Vector3.UP)
	NavigationServer3D.map_set_active(map, true)
	nav_ready.emit()
	NavigationServer3D.map_set_edge_connection_margin(get_world_3d().get_navigation_map(),3)
	update_navigation()


func set_resource(resource: String, value: int):
	UI_controller.res_displays[resource].clear()
	UI_controller.res_displays[resource].add_text(var_to_str(value))


func set_pop(current: int, max_pop: int):
	UI_controller.res_displays["pop"].clear()
	UI_controller.res_displays["pop"].add_text(var_to_str(current)+" / " + var_to_str(max_pop))


###SIGNALS FUNCTIONS###

func unit_selected(unit):
	UI_controller.close_menus()
	
	if(unit.actor_owner == player_controller):
		click_mode = "command_unit"
		if Input.is_action_pressed("multi-select"):
			selected_units.push_back(unit)
		else:
			selected_units = [unit]
		for i in selected_units:
			print(i.name)
		print("_______________")
	else:
		if click_mode == "command_unit":
			pass


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


## Activate buildings
func building_pressed(building):
	if player_controller.owns_building(building) == false:
		return
	activated_building = building #pass activated building to gamescene
	var type = building.type
	match type:
		"Base":
			player_controller.adj_resource("wood",10)
			player_controller.adj_resource("stone",10)
		"Barracks":
			player_controller.adj_resource("riches",10)
			player_controller.adj_resource("crystals",10)
			UI_controller.show_menu(1)
		_:
			pass


## Clicks on world
func ground_click(_camera, event, pos, _normal, _shape_idx, shape):
	#print(pos)
	match click_mode:
		"build":
			preview_building.set_pos(pos)
			if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
				#Close all menus when clicking on the world	
				UI_controller.close_menus()
				if player_controller.place_building(shape.get_groups()[0], preview_building):
					#Reset click mode
					click_mode = "select"
					preview_building = null
		"command_unit":
			if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
				#Close all menus when clicking on the world
				UI_controller.close_menus()
				if(selected_units.size() > 4):
					var dist = float(selected_units.size())/2
					for i in selected_units:
						i.set_mov_target(pos + Vector3(rng.randf_range(-dist,dist),0,rng.randf_range(-dist,dist)))
				else:
					for i in selected_units:
						i.set_mov_target(pos)
		_:
			pass


func _on_unit_test_button_pressed():
	activated_building.use("base")


func _on_ui_node_menu_opened():
	if(preview_building != null):
		preview_building.queue_free()
		preview_building = null
	click_mode = "select"


func _on_day_cycle_timer_timeout():
	for f in game_actors:
		f.adj_resource("food", f.units.size()* -1)
	
	if(day_cycle):
		year_day+=1
	
	if year_day > global.YEAR_LENGTH:
		year_day = 1
		year += 1

