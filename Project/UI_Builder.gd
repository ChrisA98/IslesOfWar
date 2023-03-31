extends Control

#UI Elements
@onready var menus = [$Build_Menu,$Barracks_Menu]
var buttons

#Ref Vars
@onready var game_scene = $".."


# Called when the node enters the scene tree for the first time.
func _ready():
	
	#place menus
	for i in menus:
		i.position = Vector2(int((get_viewport_rect().size.x/2)-100),int(get_viewport_rect().size.y/10))
		i.visible = false
	
	buttons = [$Time_Bar/Build_Button, $Time_Bar/Units_Button, $Minimap/Snap]


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func unpress_button(id):
	buttons[id].button_pressed = false


func show_menu(menu_id):
	menus[menu_id].visible = true


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
