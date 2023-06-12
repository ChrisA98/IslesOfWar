extends Control

#signals
signal menu_opened
signal minimap_clicked

## minimap vars
@onready var world_width = $"../World/Visual_Ground".mesh.size.x
@onready var mtw_ratio = world_width/$Minimap/Minimap_Container.size.x
@onready var player_cam = get_node("../Player/Player_camera")
@onready var viewport_ref = get_node("Minimap/Minimap_Container/SubViewport/Viewport")

@onready var gamescene = get_node("..")
## UI Elements
@onready var menus = [$Build_Menu]
@onready var unit_bar = get_node("Unit_List")
@onready var minmap = get_node("Minimap")
@onready var res_displays = {"wood": $Minimap/Res_Bar/Wood/Amount,
"stone": $Minimap/Res_Bar/Stone/Amount,
"riches": $Minimap/Res_Bar/Riches/Amount,
"crystals": $Minimap/Res_Bar/Crystal/Amount,
"food": $Minimap/Res_Bar/Food/Amount,
"pop": $Minimap/Pop}
@onready var global = get_node("/root/Global_Vars")
var buttons := []
var act_unit_rect := []

## Ref Vars
@onready var game_scene = $".."

## Loaded  Elements
@onready var unit_rect = preload("res://Game_Scene_Files/UI_Elements/unit_rect.tscn")


## Called when the node enters the scene tree for the first time.
func _ready():
	$Time_Bar/Day_Cycle_Timer.start(global.DAY_LENGTH)
	update_clock()
	
	#place menus
	for i in menus:
		i.visible = false
	
	
	for i in minmap.get_child(1).get_children():
		if i.name.contains("Button"):
			buttons.push_back(i)
	
	setup_particles()


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):	
	viewport_ref.position.x = ((player_cam.position.x + world_width/2)*mtw_ratio) - (viewport_ref.size.x/2)
	viewport_ref.position.y = (player_cam.position.z + world_width/2) - (viewport_ref.size.y/2)*mtw_ratio


## Toggle button (may not be useful)
func unpress_button(id):
	buttons[id].button_pressed = false


func setup_particles():
	#setup unit list particles
	var trgt_w = $Unit_List.size.x
	var trgt_p = Vector2($Unit_List.position.x+(trgt_w/2.1),$Unit_List.size.y)
	
	$Unit_List/Magic_Particles.position = trgt_p
	var u_mat = $Unit_List/Magic_Particles.get_process_material()
	u_mat.set_emission_box_extents(Vector3(trgt_w/2,0,1))

	pass


## Show target menu
func show_menu(menu_id):
	menus[menu_id].visible = true
	menu_opened.emit()


## Close all menus
func close_menus():
	for m in menus:
		if m.visible:
			m.visible = false
	for b in buttons:
		b.visible = true


## Close targeted menu
func close_menu(menu):
	menus[menu].visible = false
	for b in buttons:
		b.visible = true


## Show unit build menu
func set_unit_list(unit_list = null):
	if(unit_list == null):
		unit_bar.visible = false
		return	
	for i in act_unit_rect:
		i.queue_free()
	act_unit_rect = []
	unit_bar.visible = true
	for unit in unit_list:
		add_unit_rect(unit,unit_list[unit])


## Add rectangle for unit
func add_unit_rect(unit, list):
	var r = unit_rect.instantiate()
	r.get_node("Unit_count").text = "[font_size={15}][color=black]"+str(list.size())+"[/color][/font_size]"
	r.get_node("Unit_name").text = "[font_size={12}][color=black]"+unit+"[/color][/font_size]"
	r.init(unit)
	r.pressed.connect(gamescene.select_from_list)
	unit_bar.add_child(r)
	act_unit_rect.push_back(r)
	act_unit_rect[-1].anchor_left = 0.025 + (act_unit_rect.size()-1)*.15
	act_unit_rect[-1].anchor_right = 0.125 + (act_unit_rect.size()-1)*.15


## Show build menu
func _on_build_button_pressed():
	show_menu(0)
	for i in buttons:
		i.visible = false


## Snap to grid button
func _on_snap_pressed():
	var snap_button = buttons[0]
	match snap_button.text:
		"Snap":
			snap_button.text = "x5"
			game_scene.set_map_snap(5)
		"x5":
			snap_button.text = "x10"
			game_scene.set_map_snap(10)
		"x10":
			snap_button.text = "x15"
			game_scene.set_map_snap(15)
		"x15":
			snap_button.text = "Snap"
			game_scene.set_map_snap(0)


## This does the wrong thing FIX IT
func _on_units_button_pressed():
	print("Why didn't you just implement the menu spongebob")


## Update clock
func update_clock():
	if(game_scene.day_cycle):
		$Time_Bar/Day_Cycle_Timer.start(global.DAY_LENGTH)
	else:
		$Time_Bar/Day_Cycle_Timer.start(global.NIGHT_LENGTH)
	$Time_Bar/BoxContainer/Date.clear()
	$Time_Bar/BoxContainer/Date.push_color(Color.BLACK)
	$Time_Bar/BoxContainer/Date.add_text(global.month_to_string(game_scene.year_day,game_scene.year))


## Minimap input event
func minimap_Input(event):
	var world_pos = (event.position * mtw_ratio)
	# Minimap is left clicked once
	if Input.is_action_just_released("lmb"):
		world_pos.x -= world_width/2
		world_pos.y -= world_width/2
		minimap_clicked.emit("move_cam",world_pos)	
