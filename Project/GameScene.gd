extends Node3D

#ref vars
@onready var cam = $Player_camera/Player_view
@onready var UI_controller = $UI_Node
@onready var world = $World
@onready var player_faction = preload("res://Faction_Resources/Amerulf_Resource.json")
var buildings = []
var units = []
var menu_buildings = []
var world_buildings = []
var forts = []

var rng = RandomNumberGenerator.new()

#Game logic vars
var building_snap = 0
var preview_building: Node3D
var click_mode: String = "select"
var activated_building = null
var selected_units = []


#Player Resoureces
@onready var resources = {"wood": 0,
"stone": 0,
"riches": 0,
"crystals": 0,
"food": 0,
"pop": 0}
var max_pop = 0

###BUILT IN FUNCTIONS###
#Called when the node enters the scene tree for the first time.
func _ready():
	#get building buttons UI element ref
	menu_buildings = $UI_Node/Build_Menu/Building_Buttons.get_popup()
	menu_buildings.id_pressed.connect(prep_building)
	
	
	#Set resourcest to 0 at start
	for r in resources:
		set_resource(r,0)
	
	
	#load player faction with relevant JSON
	player_faction.stringify(load("res://Faction_Resources/Amerulf_Resource.json"))
	
	#Load building scenes from JSON data
	for b in player_faction.data.buildings:
		buildings.push_back(load("res://Buildings/"+b+".tscn"))
		menu_buildings.add_item(b)


#Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


###GAME FUNCTIONS###
func set_map_snap(snp):
	building_snap = snp
	if preview_building != null:
		preview_building.set_snap(snp)


#whats on the tin
func place_building():	
	if preview_building.is_valid == false:
		return
	
	#spend resources
	for res in preview_building.cost:
		adj_resource(res,preview_building.cost[res]*-1)
	
	#hide fort radius
	for i in forts:
			i.hide_radius()
	
	#connect signals
	preview_building.activated.connect(building_activated)
	
	#place forts in fort list
	if preview_building.type == "Main":
		forts.push_back(preview_building)
	#place building in world
	world_buildings.push_back(preview_building)
	preview_building = null
	world_buildings[-1].place()
	world.update_navigation_mesh()
	
	#adjust max pop
	adj_pop_limit(world_buildings[-1].pop_mod)
	#reset click mode
	click_mode = "select"


func set_pop_limit(amt: int):
	max_pop = amt
	UI_controller.res_displays["pop"].clear()
	UI_controller.res_displays["pop"].add_text(var_to_str(resources["pop"]))
	UI_controller.res_displays["pop"].add_text(" / " + var_to_str(max_pop))


func adj_pop_limit(amt: int):
	max_pop += amt
	UI_controller.res_displays["pop"].clear()
	UI_controller.res_displays["pop"].add_text(var_to_str(resources["pop"]))
	UI_controller.res_displays["pop"].add_text(" / " + var_to_str(max_pop))


func update_pop():
	var _units = 0
	for i in units:
		_units += i.unit_cost
	set_resource("pop",_units)


func spawn_unit(unit) -> bool:
	if unit.unit_cost+ resources["pop"] >= max_pop:
		return false
	for res in unit.res_cost:
		if resources[res] - unit.res_cost[res] < 0:
			return false
	for res in unit.res_cost:
		adj_resource(res,unit.res_cost[res]*-1)
	add_child(unit)
	units.push_back(unit)
	unit.unit_list = units
	unit.selected.connect(unit_selected)
	update_pop()
	return true


#setup navigation
func custom_nav_setup():
	#create navigation map
	var map: RID = NavigationServer3D.map_create()
	NavigationServer3D.map_set_up(map, Vector3.UP)
	NavigationServer3D.map_set_active(map, true)
		
	await get_tree().physics_frame
	# query the path from the navigationserver
	var start_position: Vector3 = Vector3(0.1, 0.0, 0.1)
	var target_position: Vector3 = Vector3(1.0, 0.0, 1.0)
	var optimize_path: bool = true

	var path: PackedVector3Array = NavigationServer3D.map_get_path(
		map,
		start_position,
		target_position,
		optimize_path)


func set_resource(resource: String, value: int):
	resources[resource] = value
	UI_controller.res_displays[resource].clear()
	UI_controller.res_displays[resource].add_text(var_to_str(value))
	if resource == "pop":
		UI_controller.res_displays[resource].add_text(" / " + var_to_str(max_pop))


func adj_resource(resource: String, value: int):
	resources[resource] += value
	UI_controller.res_displays[resource].clear()
	UI_controller.res_displays[resource].add_text(var_to_str(resources[resource]))
	if resource == "pop":
		UI_controller.res_displays[resource].add_text(" / " + var_to_str(max_pop))


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
	world.add_child(new_build)
	new_build.init(position, building_snap)
	preview_building = new_build
		
	if(preview_building.name != "Fort"):
		for i in forts:
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
			adj_resource("wood",10)
			adj_resource("stone",10)
		"Barracks":
			adj_resource("riches",10)
			adj_resource("crystals",10)
			UI_controller.show_menu(1)
		_:
			pass


#Clicks on world
func _on_static_body_3d_input_event(_camera, event, position, _normal, _shape_idx):	
	match click_mode:
		"build":
			preview_building.set_pos(position-world.position)
			if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
				#Close all menus when clicking on the world	
				UI_controller.close_menus()
				if preview_building.is_valid == false:
					return
				else:
					place_building()
		"command_unit":
			if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
				#Close all menus when clicking on the world	
				UI_controller.close_menus()
				if(selected_units.size() > 4):
					var dist = selected_units.size()/2
					for i in selected_units:
						i.set_mov_target(position + Vector3(rng.randf_range(-dist,dist),0,rng.randf_range(-dist,dist)))
				else:
					for i in selected_units:
						i.set_mov_target(position)
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
	adj_resource("food",units.size())
