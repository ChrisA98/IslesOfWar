extends Node3D

#ref vars
@onready var UI_controller = $UI_Node
@onready var world = $World
@onready var player_controller = $Player
@onready var player_faction = preload("res://Faction_Resources/Amerulf_Resource.json")
@onready var global = get_node("/root/Global_Vars")
var ground_group = &"navigation_mesh"
var buildings = []
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
	
	#Connect player signals
	player_controller.res_changed.connect(set_resource)
	player_controller.pop_changed.connect(set_pop)
	
	#Get building buttons UI element ref
	menu_buildings = $UI_Node/Build_Menu/Building_Buttons.get_popup()
	menu_buildings.id_pressed.connect(prep_building)
	
	#Load building scenes from JSON data
	for b in player_faction.data.buildings:
		buildings.push_back(load("res://Buildings/"+b+".tscn"))
		menu_buildings.add_item(b)
		
	call_deferred("custom_nav_setup")


#Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


###GAME FUNCTIONS###
func set_map_snap(snp):
	building_snap = snp
	if preview_building != null:
		preview_building.set_snap(snp)


#whats on the tin
func place_building(grp):	
	if preview_building.is_valid == false:
		return null
	
	#Connect signals
	preview_building.activated.connect(building_activated)
	
	#Place building in world
	world_buildings.push_back(preview_building)
	preview_building.place()
	preview_building.add_to_group(grp)
	update_navigation()
	preview_building = null
	
	#Reset click mode
	click_mode = "select"
	return world_buildings[-1]


func update_navigation():
	world.update_navigation_meshes()


func spawn_unit(o_player, unit) -> bool:
	if unit.unit_cost + o_player.pop >= o_player.max_pop:
		return false
	for res in unit.res_cost:
		if o_player.resources[res] - unit.res_cost[res] < 0:
			return false
	for res in unit.res_cost:
		o_player.adj_resource(res,unit.res_cost[res]*-1)
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


func set_resource(resource: String, value: int):
	UI_controller.res_displays[resource].clear()
	UI_controller.res_displays[resource].add_text(var_to_str(value))


func set_pop(current: int, max_pop: int):
	UI_controller.res_displays["pop"].clear()
	UI_controller.res_displays["pop"].add_text(var_to_str(current)+" / " + var_to_str(max_pop))


###SIGNALS FUNCTIONS###

func unit_selected(unit):
	UI_controller.close_menus()
	click_mode = "command_unit"
	if Input.is_action_pressed("multi-select"):
		selected_units.push_back(unit)
	else:
		selected_units = [unit]
	for i in selected_units:
		print(i.name)
	print("_______________")


#prepare new building
func prep_building(id):	
	#clear existing preview buildings
	if(preview_building != null):
		preview_building.queue_free()
		preview_building = null
	
	var new_build = buildings[id].instantiate()
	add_child(new_build)
	new_build.init(position, building_snap, player_controller)
	preview_building = new_build
		
	if(preview_building.name != "Fort"):
		for i in player_controller.forts:
			i.preview_radius()
			
	#reset menu visibility
	$UI_Node/Build_Menu.visible = false
	click_mode = "build"


#activate buildings
func building_activated(building):
	activated_building = building
	var type = building.type
	match type:
		"Main":
			player_controller.adj_resource("wood",10)
			player_controller.adj_resource("stone",10)
		"Barracks":
			player_controller.adj_resource("riches",10)
			player_controller.adj_resource("crystals",10)
			UI_controller.show_menu(1)
		_:
			pass


#Clicks on world
func ground_click(_camera, event, pos, _normal, _shape_idx, shape):	
	#print(pos)
	match click_mode:
		"build":
			preview_building.set_pos(pos)
			if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
				#Close all menus when clicking on the world	
				UI_controller.close_menus()
				if preview_building.is_valid == false:
					return
				else:
					player_controller.place_building(shape.get_groups()[0])
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
	player_controller.adj_resource("food",player_controller.units.size())
	year_day+=1
	if year_day > global.YEAR_LENGTH:
		year_day = 1
		year += 1

