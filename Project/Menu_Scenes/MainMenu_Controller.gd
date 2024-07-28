extends Control

signal gamescene_loaded

var mutex: Mutex
var load_thread: Thread
var gamescene_instance
var is_loading:bool:
	set(value):
		is_loading = value
		if value:
			process_mode = Node.PROCESS_MODE_DISABLED

var player_changing_heroes: int ## Variable used to kep track of hero being set on custom game menu
var target_load_level : String = ""

@onready var main_menu = get_node("Main")
@onready var custom_game_menu = get_node("Custom Games Menu")
@onready var map_edit_menu = get_node("Map Editor Menu")

@onready var global = get_node("/root/Global_Vars")

var gamescene_path = "res://Game_Scene_Files/GameScene.tscn"

func _ready():
	#instant_load_game()
	
	## DEPRECATED used to update an initial heightmap, get rid of later if nothing ever breaks
	#var heightmap = load("res://Assets/Levels/default_map/master.exr").get_image()
	#Global_Vars.heightmap = heightmap
	#RenderingServer.global_shader_parameter_set("heightmap_tex",ImageTexture.create_from_image(heightmap))
	
	$Load_Screen.faded_in.connect(_free_background)
	
	## Play title screen animation and sound
	$Background/AnimationPlayer.play("boat_sway")
	$Background/ShipCreak.play()
	$Background/MainMenuMusic.play()
	
	##Prepare Custom Games menu
	load_maps()


## NOTE TEMPORARY INSTANT LOAD GAMESCENE
func instant_load_game():
	pass
	#var level = "Cliffs and Coasts"
	#level = level.replace(" ","_")
	#call_deferred("_load_gamescene",level)


func _process(_delta):
	$Background/MainMenu/OmniLight3D2.light_energy = clampf($Background/MainMenu/OmniLight3D2.light_energy + randf_range(-0.05,0.05),0.8,1.2);
	$Background/MainMenu/OmniLight3D.light_energy  = clampf($Background/MainMenu/OmniLight3D.light_energy + randf_range(-0.05,0.05),0.8,1.2);

#region Main Menu Buttons
func _multiplayer_button():	
	custom_game_menu.visible = true
	main_menu.visible = false


## Free background once other functionms
func _free_background():
	if $Background == null:
		return
	$Background.queue_free()

## Free Main Menu once new scene is loaded
func _exit_menu():
	print("finished loading")
	queue_free()
	gamescene_loaded.emit()


func _maps():	
	map_edit_menu.visible = true
	main_menu.visible = false


func _quit_game():
	print("test")
	get_tree().quit()
#endregion


#region Custom Games Menu Buttons

## load Maps for map selection
func load_maps():
	var dir: DirAccess
	
	## Set Level path based on whether in build or editor debug
	if OS.has_feature("editor"):
		dir = DirAccess.open("user://Assets/Levels/")
	else:
		dir = DirAccess.open(OS.get_executable_path().get_base_dir()+"/Assets/Levels/")
	
	## Load maps
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.contains("import") or file_name.contains("~"):
				## Skip import files
				file_name = dir.get_next()
				continue
			var display_name = file_name.split(".")[0].replace("_"," ")
			$"Custom Games Menu/Panel/VBoxContainer/MapSection/OptionButton".add_item(display_name)
			_create_load_map_button(display_name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")


## Create buttons with available maps
func _create_load_map_button(map_name : String):
	var button = $"Map Editor Menu/load_map/VBoxContainer/Panel/ScrollContainer/VBoxContainer/Map_Button".duplicate()
	button.text = map_name
	button.visible = true
	button.pressed.connect(_set_target_load_map.bind(map_name))
	$"Map Editor Menu/load_map/VBoxContainer/Panel/ScrollContainer/VBoxContainer".add_child(button)



##Load gamescene
func _load_gamescene(level: String):
	is_loading = true
	for i in get_children():
		i.visible = false
	$Load_Screen.fade_in()
	await $Load_Screen.faded_in
	print("Loading")
	var gamescene_load = load(gamescene_path)
	print("Scene loaded")
	var scene = gamescene_load.instantiate()
	
	var dir : DirAccess
	
	if OS.has_feature("editor"):
		dir = DirAccess.open("user://")
	else:
		dir = DirAccess.open(OS.get_executable_path().get_base_dir())
	
		
	if (!dir.dir_exists("Assets/Levels/"+level+"/")):
		print("level not found")
	
	scene.load_world(dir.get_current_dir()+"/Assets/Levels/"+level+"/level.tscn")
	scene.loaded.connect(_exit_menu)
	print("Scene instanced")
	get_tree().root.add_child(scene)


func _play_game():
	var map_select = get_node("Custom Games Menu/Panel/VBoxContainer/MapSection/OptionButton")
	var level = map_select.get_item_text(map_select.selected)
	level = level.replace(" ","_")
	call_deferred_thread_group("_load_gamescene",level)


func _show_hero_select(pid: int):
	## TODO Implement once heroes are in game
	return
	player_changing_heroes = pid
	
	## Swap Names
	$"Custom Games Menu/Panel/VBoxContainer/PlayerTitle".visible = false
	$"Custom Games Menu/Panel/VBoxContainer/Heroes".visible = true
	
	## Swap UI Elements
	$"Custom Games Menu/Panel/VBoxContainer/PlayersContainer".visible = false
	$"Custom Games Menu/Panel/VBoxContainer/HeroSelect".visible = true
	


func _leave_cg_menu():	
	custom_game_menu.visible = false
	main_menu.visible = true

#endregion


#region Maps Menu Buttons

func load_level_editor(map_size:int = 0,map_name:String = ""):
	is_loading = true
	for i in get_children():
		i.visible = false
	$Load_Screen.fade_in()
	await $Load_Screen.faded_in
	print("Loading")
	var gamescene_load = load("res://World_Generation/level_builder/level_builder.tscn")
	print("Scene loaded")
	var scene = gamescene_load.instantiate()
	print("Scene instanced")
	get_tree().root.add_child(scene)
	scene.initialize(target_load_level,map_size,map_name)
	if scene.is_node_ready() == false:
		await scene.ready
	_exit_menu()
	

## Set target load map
func _set_target_load_map(map:String):
	target_load_level = map
	for button in $"Map Editor Menu/load_map/VBoxContainer/Panel/ScrollContainer/VBoxContainer".get_children():
		if button.text != map:
			button.button_pressed = false


func _show_load_map(state:bool = true):
	$"Map Editor Menu/map_editor".visible = !state
	$"Map Editor Menu/load_map".visible = state


## Show Create map menu
func _show_create_map(state:bool = true):
	$"Map Editor Menu/map_editor".visible = !state
	$"Map Editor Menu/new_map".visible = state


## Return to main menu
func hide_map_edit_menu():
	map_edit_menu.visible = false
	main_menu.visible = true


func _create_map():
	var m_size = int($"Map Editor Menu/new_map/VBoxContainer/map_size/LineEdit".text)
	var m_name = $"Map Editor Menu/new_map/VBoxContainer/map_name/LineEdit".text
	call_deferred("load_level_editor",m_size,m_name)
	
func _update_map_size_text():
	var text = $"Map Editor Menu/new_map/VBoxContainer/map_size/LineEdit".text
	if text.is_valid_int():
		text = int(text)
		text = clampi((text/500)*500,500,3000)
	else:
		text = ""
	$"Map Editor Menu/new_map/VBoxContainer/map_size/LineEdit".text = str(text)

#endregion
