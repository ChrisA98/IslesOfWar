extends Control

signal gamescene_loaded

var mutex: Mutex
var load_thread: Thread
var gamescene_instance
var is_loading

@onready var main_menu = get_node("Main")

var gamescene_path = "res://Game_Scene_Files/GameScene.tscn"



func _multiplayer_button():
	print("test")
	call_deferred("_load_gamescene")


func _load_gamescene():
	is_loading = true
	mutex = Mutex.new()
	load_thread = Thread.new()
	for i in get_children():
		i.visible = false
	$Load_Screen.fade_in()
	$Background.queue_free()
	get_tree().set_pause(true)
	load_thread.start(_load_gamescene_thread.bind(gamescene_path))
	await gamescene_loaded
	get_tree().set_pause(false)
	queue_free()


func _load_gamescene_thread(path):
	print("loading")
	var gamescene_load = load(path)
	var scene = gamescene_load.instantiate()
	while !scene.ready_to_load:
		print("...")
	get_tree().root.call_deferred("add_child",scene)
	await scene.loaded
	print("finished loading")
	gamescene_loaded.emit()


func _exit_tree():
	if is_loading:
		load_thread.wait_to_finish()


func _maps():
	print("waiting....")


func _quit_game():
	print("test")
	get_tree().quit()
