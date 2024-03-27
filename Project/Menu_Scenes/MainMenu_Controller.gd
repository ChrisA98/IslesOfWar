extends Control

signal gamescene_loaded

var mutex: Mutex
var load_thread: Thread
var gamescene_instance
var is_loading

@onready var main_menu = get_node("Main")
@onready var global = get_node("/root/Global_Vars")

var gamescene_path = "res://Game_Scene_Files/GameScene.tscn"

func _ready():	
	var heightmap = load("res://Assets/Levels/default_map/master.exr").get_image()
	Global_Vars.heightmap = heightmap
	RenderingServer.global_shader_parameter_set("heightmap_tex",ImageTexture.create_from_image(heightmap))
	$Load_Screen.faded_in.connect(_free_background)

func _multiplayer_button():
	call_deferred("_load_gamescene")


func _load_gamescene():
	is_loading = true
	for i in get_children():
		i.visible = false
	$Load_Screen.fade_in()
	await get_tree().physics_frame
	print("Loading")
	var gamescene_load = load(gamescene_path)
	print("Scene loaded")
	var scene = gamescene_load.instantiate()
	scene.loaded.connect(_exit_menu)
	print("Scene instanced")
	get_tree().root.add_child(scene)


## Free background once other functionms
func _free_background():
	$Background.queue_free()

## Free Main Menu once new scene is loaded
func _exit_menu():
	print("finished loading")
	queue_free()
	gamescene_loaded.emit()


func _maps():
	print("waiting....")


func _quit_game():
	print("test")
	get_tree().quit()
