extends Control

signal gamescene_loaded

var mutex: Mutex
var load_thread: Thread
var gamescene_instance

@onready var main_menu = get_node("Main")

var gamescene_path = "res://Game_Scene_Files/GameScene.tscn"


func _multiplayer_button():
	print("test")
	call_deferred("_load_gamescene")


func _load_gamescene():
	mutex = Mutex.new()
	load_thread = Thread.new()
	for i in get_children():
		i.visible = false
	$fade.visible = true
	$fade/AnimationPlayer.play("fade")
	$Background.queue_free()
	$load_screen.visible = true
	load_thread.start(_load_gamescene_thread.bind(gamescene_path))
	await gamescene_loaded
	queue_free()


func _load_gamescene_thread(path):
	print("loading")
	var gamescene_load = load(path)
	var scene = gamescene_load.instantiate()
	get_tree().root.call_deferred("add_child",scene)
	await scene.loaded
	print("loaded")
	gamescene_loaded.emit()


func _exit_tree():
	load_thread.wait_to_finish()


func _maps():
	print("waiting....")


func _quit_game():
	print("test")
	get_tree().quit()
