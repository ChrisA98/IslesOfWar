extends Control

#signals
signal menu_opened


#UI Elements
@onready var menus = [$Build_Menu,$Barracks_Menu]
@onready var res_displays = {"wood": $Res_Bar/Wood/Amount,
"stone": $Res_Bar/Stone/Amount,
"riches": $Res_Bar/Riches/Amount,
"crystals": $Res_Bar/Crystal/Amount,
"food": $Res_Bar/Food/Amount,
"pop": $Res_Bar/Pop/Amount}
@onready var global = get_node("/root/Global_Vars")
var buttons

#Ref Vars
@onready var game_scene = $".."


# Called when the node enters the scene tree for the first time.
func _ready():
	$Time_Bar/Date.add_text("3rd, Corvusan Mal, 545 E2")
	
	#place menus
	for i in menus:
		i.position = Vector2(int((get_viewport_rect().size.x/2)-100),int(get_viewport_rect().size.y/10))
		i.visible = false
	
	buttons = [$Time_Bar/Build_Button, $Time_Bar/Units_Button, $Minimap/Snap]


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func unpress_button(id):
	buttons[id].button_pressed = false


func show_menu(menu_id):
	menus[menu_id].visible = true
	menu_opened.emit()

func close_menus():
	for m in menus:
		if m.visible:
			m.visible = false


func _on_build_button_pressed():
	show_menu(0)


func _on_snap_pressed():
	match buttons[2].text:
		"None":
			buttons[2].text = "5"
			game_scene.set_map_snap(5)
		"5":
			buttons[2].text = "10"
			game_scene.set_map_snap(10)
		"10":
			buttons[2].text = "15"
			game_scene.set_map_snap(15)
		"15":
			buttons[2].text = "None"
			game_scene.set_map_snap(0)


func _on_units_button_pressed():
	show_menu(1)


func _on_timer_timeout():
	if(game_scene.day_cycle):
		$Time_Bar/Day_Cycle_Timer.start(global.NIGHT_LENGTH)
	else:
		$Time_Bar/Day_Cycle_Timer.start(global.DAY_LENGTH)
	game_scene.day_cycle = !game_scene.day_cycle
	$Time_Bar/Date.clear()
	$Time_Bar/Date.add_text(global.month_to_string(game_scene.year_day,game_scene.year))
