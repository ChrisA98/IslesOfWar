extends Node

var thread: Thread
var mutex : Mutex
var semaphore: Semaphore
var do_save: bool = false
var exit_thread : bool = false

func _ready():	
	mutex = Mutex.new()
	semaphore = Semaphore.new()
	thread = Thread.new()
	thread.start(_thread_process, Thread.PRIORITY_LOW)

##Tell node to save next process frame
func save_map():
	print("saving..")
	semaphore.post()
	get_parent().save_exists = true


func _thread_process():
	while true:
		semaphore.wait()
		
		mutex.lock()
		var should_exit = exit_thread # Protect with Mutex.
		mutex.unlock()

		if should_exit:
			break
		
		_save_map()
		
		mutex.lock()
		$"../UI/saving_icon".visible = false
		mutex.unlock()


## Create a level scene from the data in the curent scene
func _save_map():
	mutex.lock()
	var level_name = get_parent().level_name
	var level_year = get_parent().level_year
	var level_year_day = get_parent().level_year_day
	var level_rndm_spawns = get_parent().level_uses_rnd_spawns
	mutex.unlock()
	## Create Scene from bas scene file
	var level_out_scene = load("res://World_Generation/base_level.tscn").instantiate()
	
	var dir : DirAccess
	
	## Set dir based on whether in build or editor debug
	if OS.has_feature("editor"):
		dir = DirAccess.open("user://")
	else:
		dir = DirAccess.open(OS.get_executable_path().get_base_dir())
	
		
	if (!dir.dir_exists("Assets/Levels/"+level_name+"/")):
		print(dir.make_dir_recursive("Assets/Levels/"+level_name+"/"))
		
	_store_heightmap(dir.get_current_dir()+"/Assets/Levels/"+level_name+"/")
	
	## Transfer Basic Map Data
	mutex.lock()
	#level_out_scene.set_ground_tex(ImageTexture.create_from_image(_create_out_texture()))
	var ground_tex = _create_out_texture()
	ground_tex.save_png(dir.get_current_dir()+"/Assets/Levels/"+level_name+"/ground_tex.png")
	level_out_scene.heightmap_dir = dir.get_current_dir()+"/Assets/Levels/"+level_name+"/"
	level_out_scene.water_table = get_parent().ui_node.water_level
	level_out_scene.year = level_year
	level_out_scene.year_day = level_year_day
	level_out_scene.use_random_base_spawns = level_rndm_spawns
	mutex.unlock()
	
	mutex.lock()
	var collecton_of_nodes = $"../level".get_children()
	mutex.unlock()
	## Get elements of world to save
	for node in collecton_of_nodes:
		if node is WorldObjectEditor:
			mutex.lock()
			var n_node = node.get_world_object().duplicate()
			mutex.unlock()
			level_out_scene.add_child(n_node)
			n_node.position = node.position
			n_node.set_owner(level_out_scene)
		elif node is ObjectEditor:
			mutex.lock()
			var n_node = node.get_world_object().duplicate()
			mutex.unlock()
			match node.node_to_save:
				"BaseSpawn":
					level_out_scene.find_child("Base_Spawns").add_child(n_node)
					n_node.position = node.position
					n_node.name = "Base_Spawn"
				"Decor":
					level_out_scene.add_child(n_node)
					n_node.position += node.position
			n_node.set_owner(level_out_scene)
	
	## Pack and Save Scene
	var packed_scene: PackedScene = PackedScene.new()
	packed_scene.pack(level_out_scene)
	
	ResourceSaver.save(packed_scene,dir.get_current_dir()+"/Assets/Levels/"+level_name+"/level.tscn",0)
	level_out_scene.free()
	
	print("finished_saving")


## Bake ground textures to a master texture file
## NOTE: 2000x2000 is the base texture size
func _create_out_texture() -> Image:
	var chunk_map = get_parent().chunk_map
	## Base Texture to write to
	var groundImage = Image.create(2000*chunk_map.size(),2000*chunk_map.size(),true,Image.FORMAT_RGBA8)
	
	## Stitch all ground textures together
	for x in range(chunk_map.size()):
		for y in range(chunk_map.size()):
			groundImage.blend_rect(chunk_map[x][y].ground_tex,Rect2i(0,0,2000,2000),Vector2i(y*2000,x*2000))
	
	groundImage.generate_mipmaps()
	
	return groundImage


func _store_heightmap(filepath:String):
	var heightmap : Image = get_parent().heightmap
	heightmap.convert(Image.FORMAT_RGBA8)
	## Save master file
	print(heightmap.save_png(filepath+"master.png"))
	
	var map_size = get_parent().chunk_map.size()
	
	var chunk_image: Image
	## Split heightmap textures
	for x in range(map_size):
		for y in range(map_size):
			chunk_image = heightmap.get_region(Rect2i(x*500-x,y*500-y,501,501))
			chunk_image.save_png(filepath+"chunk_"+str(y)+"_"+str(x)+".png")
	


func _exit_tree():
	# Set exit condition to true.
	mutex.lock()
	exit_thread = true # Protect with Mutex.
	mutex.unlock()

	# Unblock by posting.
	semaphore.post()

	# Wait until it exits.
	thread.wait_to_finish()
