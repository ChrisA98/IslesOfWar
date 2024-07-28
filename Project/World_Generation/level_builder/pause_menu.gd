extends Panel

		

## Hide Pause menu away
func hide_pause_menu():
	$"../pause_curtain".visible = false
	visible = false
	get_parent().get_parent().process_mode = Node.PROCESS_MODE_INHERIT

func _save_map():
	visible = false
	$"../save_menu".visible = true


func _load_heightmap():
	pass


## Show exit menu
func _show_exit_menu():
	visible = false
	$"../exit_menu".visible = true


## Hide Exit menu
func _hide_exit_menu():
	visible = true
	$"../exit_menu".visible = false
	

## Load main mnenu
func return_to_main_menu():
	$"../load_cover".visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN) 
	await  get_tree().physics_frame
	var menu_load = load("res://Menu_Scenes/main_menu.tscn")
	var scene = menu_load.instantiate()
	get_tree().root.add_child(scene)
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED) 
	if scene.is_node_ready() == false:
		await scene.ready	
	get_parent().get_parent().free()


## Exit to desktop
func _exit_game():
	get_tree().quit()


