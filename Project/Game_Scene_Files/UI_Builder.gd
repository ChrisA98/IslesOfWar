extends Control

#signals
signal menu_opened


@onready var gamescene = get_node("..")
#UI Elements
@onready var menus = [$Build_Menu]
@onready var unit_bar = get_node("Unit_List")
@onready var minmap = get_node("Minimap")
@onready var res_displays = {"wood": $Res_Bar/Wood/Amount,
"stone": $Res_Bar/Stone/Amount,
"riches": $Res_Bar/Riches/Amount,
"crystals": $Res_Bar/Crystal/Amount,
"food": $Res_Bar/Food/Amount,
"pop": $Minimap/Pop}
@onready var global = get_node("/root/Global_Vars")
var buttons := []
var act_unit_rect := []

#Ref Vars
@onready var game_scene = $".."

# loaded  Elements
@onready var unit_rect = preload("res://Game_Scene_Files/UI_Elements/unit_rect.tscn")


# Called when the node enters the scene tree for the first time.
func _ready():
	$Time_Bar/Day_Cycle_Timer.start(global.DAY_LENGTH)
	update_clock()
	
	#place menus
	for i in menus:
		i.visible = false
	
	
	for i in minmap.get_children():
		if i.name.contains("Button"):
			buttons.push_back(i)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


## Toggle button (may not be useful)
func unpress_button(id):
	buttons[id].button_pressed = false


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
	match buttons[2].text:
		"Snap":
			buttons[2].text = "x5"
			game_scene.set_map_snap(5)
		"x5":
			buttons[2].text = "x10"
			game_scene.set_map_snap(10)
		"x10":
			buttons[2].text = "x15"
			game_scene.set_map_snap(15)
		"x15":
			buttons[2].text = "Snap"
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
	$Time_Bar/Date.clear()
	$Time_Bar/Date.add_text(global.month_to_string(game_scene.year_day,game_scene.year))
