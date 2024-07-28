extends Node3D

signal brush_changed
signal chunks_created

const CHUNK_SIZE = 500

enum Edit_Mode {TERRAIN,OBJECTS,ATMOSPHERE,GROUND}

@export_range(500,10000,500) var map_size = 1000

var heightmap: Image
var chunk_map = []

## Level info
var level_name : String = "map"
var level_year : int = 0
var level_year_day: int = 0
var level_uses_rnd_spawns : bool = false
var save_exists := false

var current_edit_mode : Edit_Mode = Edit_Mode.TERRAIN:
	set(value):
		current_edit_mode = value
		match current_edit_mode:
			Edit_Mode.TERRAIN:
				deselect_objects()
				cursor.visible = true
				Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
				process_function = Callable(_terrain_process)
				phys_process_function = Callable(_terrain_phys_process)
				ground_click_func = Callable(_click_terrain_brush)
			Edit_Mode.OBJECTS:
				cursor.visible = false
				Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
				process_function = Callable(_object_process)
				ground_click_func = Callable(_click_terrain_object)
				for obj in get_tree().get_nodes_in_group("editor_object"):
					obj.active = true
				return
			Edit_Mode.ATMOSPHERE:
				deselect_objects()
				cursor.visible = false
				Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
			Edit_Mode.GROUND:
				deselect_objects()
				cursor.visible = true
				Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
				process_function = Callable(_paint_process)
				ground_click_func = Callable(_click_terrain_brush)
			
		## Disable editor objects when not in placement mode
		for obj in get_tree().get_nodes_in_group("editor_object"):
			obj.active = false
## Cursor info
var mouse_held := false
var mouse_position : Vector3
var active_chunk

## Terrain update cycle
var update_cycle_x = 0
var update_cycle_y = 0

## Undo Vars
var undo_cache = []
var undo_max_size = 32000

## Clipboard
var copied_item : Node

## Placed object arrays
var world_objects := []
var object_update_cycle: int

## Terrain texture array
var terrain_textures : Dictionary

@onready var ground_prev = get_node("visual_ground")
@onready var cursor = get_node("editor_cursor")
@onready var cam_controller = get_node("Editor_Cam")
@onready var ui_node = get_node("UI")
@onready var save_node = get_node("off_thread_save")
@onready var process_function = Callable(_terrain_process)
@onready var phys_process_function = Callable(_terrain_phys_process)
@onready var ground_click_func = Callable(_click_terrain_brush)


func initialize(map_path: String = "", map_size_n: int = 500, map_name:String = ""):
	if map_path == "":
		set_data(map_size_n,map_name)
		_generate_main_heightmap()
	else:
		## Load heightmap from file
		map_path = map_path.replace(" ","_")
		var dir : DirAccess
		if OS.has_feature("editor"):
			dir = DirAccess.open("user://")
		else:
			dir = DirAccess.open(OS.get_executable_path().get_base_dir())		
		_load_heightmap(dir.get_current_dir()+"/Assets/Levels/"+map_path)
		call_deferred("load_map",map_path)
	call_deferred("_populate_chunks")
	_update_heightmap_master()
	
	ui_node.edit_mode_changed.connect(_change_edit_mode)
	
	## Set Blank texture to global shader variable so Trees can render
	var img = Image.create(map_size,map_size,false,Image.FORMAT_RGBF)
	img.fill(Color(0,0,0,0))
	RenderingServer.global_shader_parameter_set("building_locs",ImageTexture.create_from_image(img))
	
	#Load textures for terrain brush
	load_textures()
	ready.emit()


func set_data(map_size_n:int,map_name:String):
	map_size=map_size_n
	level_name = map_name
	$UI/save_menu/VBoxContainer/level_name.text = map_name


func _process(_delta):
	cursor.position = mouse_position
	process_function.call()


func _physics_process(_delta):
	phys_process_function.call()
	

func _input(event):
	if event.is_action_pressed("ui_text_delete"):
		for obj in get_tree().get_nodes_in_group("editor_object"):
			if obj.has_method("delete_node"):
				obj.delete_node()
	## TODO: Make this copy paste script stuff work later
	## Will need alot more implementation
	##if event.is_action_pressed("ui_copy") and current_edit_mode == Edit_Mode.OBJECTS:
	##	for obj in get_tree().get_nodes_in_group("editor_object"):
	##		if obj.selected == true:
	##			copied_item = obj.duplicate()
	##if event.is_action_pressed("ui_paste") and current_edit_mode == Edit_Mode.OBJECTS:
	##	var n_item = copied_item.duplicate(DuplicateFlags.DUPLICATE_USE_INSTANTIATION )
	##	$level.add_child(n_item)
	##	add_world_object(n_item)
	##	n_item.following_mouse = true
	##	n_item.following_mouse = false
	


## Set last brush stroke to undo cache
func _push_undo():
	if(undo_cache.size() > undo_max_size):
		undo_cache.pop_front()
	undo_cache.push_back([mouse_position,cursor.get_draw_tex(),cursor.radius])

#region Load Data Functions

## Create initial map with flat terrain
func _generate_main_heightmap(_def = null):
	heightmap = Image.create(map_size,map_size,false,Image.FORMAT_RGBA8)
	heightmap.fill(Color(.1,.1,.1,1))
	_update_heightmap_master()
	#


## Load Heightmap from file
func _load_heightmap(map_path: String):
	heightmap = Image.load_from_file(map_path+"/master.png")
	map_size = heightmap.get_height()
	
	if heightmap.is_compressed():
		heightmap.decompress()
	
	heightmap.convert(Image.FORMAT_RGBA8)
	_update_heightmap_master()


## Create a noise generated Heightmap randomly
func _generate_random_heightmap():
	var random_noise = NoiseTexture2D.new()
	random_noise.set_width(map_size)
	random_noise.set_height(map_size)
	random_noise.noise = FastNoiseLite.new()
	random_noise.noise.set_noise_type(FastNoiseLite.TYPE_PERLIN)
	random_noise.noise.seed = randi()
	random_noise.noise.frequency = 0.001
	random_noise.noise.domain_warp_enabled = true
	random_noise.noise.set_domain_warp_fractal_gain(.1)
	random_noise.noise.set_domain_warp_frequency (.002)
	await random_noise.changed
	heightmap = random_noise.get_image()
	heightmap.convert(Image.FORMAT_RGBA8)
	_update_heightmap_master()


## Load Textures for terrain painting brush
func load_textures():
	var dir = DirAccess.open("res://Assets/Terrain_Textures/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.contains("import") or file_name.contains("~"):
				## Skip import files
				file_name = dir.get_next()
				continue
			# Remove .remap extension if present
			if file_name.ends_with(".remap"):
				file_name = file_name.substr(0, file_name.length() - 6)
			## Trim File Extension for button
			var display_name = file_name.split(".")[0].replace("_"," ")
			if file_name.ends_with(".png"):
				terrain_textures[display_name] = Image.load_from_file("res://Assets/Terrain_Textures/"+file_name)
			elif file_name.ends_with(".tres"):
				terrain_textures[display_name] = load("res://Assets/Terrain_Textures/"+file_name)
			else:
				print("Failed to load: "+file_name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	
	ui_node.load_textures()
	

#endregion


#region Process Functions


## Terrain brush process function
func _terrain_process():
	if mouse_held and !ui_node.mouse_used:
		active_chunk.draw_brush_to_map(mouse_position,cursor.get_draw_tex(),cursor.radius)
		_push_undo()
		if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			mouse_held = false
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		call_deferred("_generate_random_heightmap")
	
	## Update objects in cycles
	if object_update_cycle >= world_objects.size():
		object_update_cycle = 0
	if world_objects.size() == 0:
		return
	world_objects[object_update_cycle].update_node()
	object_update_cycle += 1


## Terrain brush process function
func _terrain_phys_process():
	if chunk_map.size() == 0:
		return
	
	_object_process()
	
	update_cycle_y += 1
	if update_cycle_y >= chunk_map.size():
		update_cycle_x +=1
		update_cycle_y = 0
		if update_cycle_x >= chunk_map.size():
			update_cycle_x = 0
	
	update_chunk_map_tex(update_cycle_x,update_cycle_y)


## Terrain brush process function
func _paint_process():
	if mouse_held and !ui_node.mouse_used:
		active_chunk.paint_brush_to_terrain(mouse_position, cursor.draw_img, cursor.paint_tex)
		if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			mouse_held = false
		
	update_cycle_y += 1
	if update_cycle_y >= chunk_map.size():
		update_cycle_x +=1
		update_cycle_y = 0
		if update_cycle_x >= chunk_map.size():
			update_cycle_x = 0


## place object process function
func _object_process():
	pass

#endregion


#region Interact Functions



## changed brush mode
func brush_mode_changed(id):
	brush_changed.emit(id)


## Ground Shape interacted with
func ground_click(camera, event:InputEvent, pos:Vector3, normal, shape_idx, chunk):
	active_chunk = chunk
	if (pos).length() != 0:
		mouse_position = lerp(mouse_position,pos,.25)
	ground_click_func.call(camera, event, pos, normal, shape_idx, chunk)


## On ground click with terrain brush
func _click_terrain_brush(_camera, event:InputEvent, _pos:Vector3, _normal, _shape_idx, _chunk):
	if event is InputEventMouseButton:
		if event.button_index == 1:
			mouse_held = event.is_pressed()


## On ground click with object placement
func _click_terrain_object(_camera, event:InputEvent, _pos:Vector3, _normal, _shape_idx, _chunk):
	if event is InputEventMouseButton:
		if event.button_index == 1:
			deselect_objects()



#endregion


#region Edit Chunks

## Create brushes at start of level
func _populate_chunks():
	@warning_ignore("integer_division")
	var chunks = map_size/CHUNK_SIZE
	
	var chunk_template = load("res://World_Generation/level_builder/editor_chunk.tscn").instantiate()
	
	## implement instanced chunks
	for y in range(chunks):
		var row = []
		for x in range(chunks):
			var new_chunk =  chunk_template.duplicate()
			new_chunk.mesh = chunk_template.mesh.duplicate()
			new_chunk.mesh.material = load("res://World_Generation/level_builder/editor_chunk_material.tres").duplicate()
			new_chunk.chunk_x = x
			new_chunk.chunk_y = y
			new_chunk.position.x = x*CHUNK_SIZE
			new_chunk.position.z = y*CHUNK_SIZE
			new_chunk.name = "chunk_"+str(y)+"_"+str(x)
			row.push_back(new_chunk)
			ground_prev.add_child(new_chunk)
			new_chunk.collision_body.input_event.connect(ground_click.bind(new_chunk))
			new_chunk.updated_map.connect(_update_heightmap_master)
			brush_changed.connect(new_chunk._change_brush_function)
			new_chunk.call_deferred("load_ground_tex")
		chunk_map.push_back(row)
	create_chunks()
	@warning_ignore("integer_division")
	ground_prev.position.x -= (CHUNK_SIZE*(chunks-1))/2
	@warning_ignore("integer_division")
	ground_prev.position.z -= (CHUNK_SIZE*(chunks-1))/2
	chunks_created.emit()


func _update_heightmap_master():
	Global_Vars.heightmap = heightmap
	Global_Vars.heightmap_size = map_size
	var hm_tex = ImageTexture.create_from_image(heightmap)
	RenderingServer.global_shader_parameter_set("heightmap_tex",hm_tex)
	RenderingServer.global_shader_parameter_set("heightmap_tex_size",Vector2(map_size,map_size))


## Generate all chunk textures
func create_chunks():
	@warning_ignore("integer_division") var length = round(map_size / CHUNK_SIZE)
	for y in range(0,length):
		for x in range(0,length):
			update_chunk_map_tex(x,y)


## Get chunk of total heightmap and assign it to local chunk
func update_chunk_map_tex(x,y):
	if (!chunk_map[x][y].is_node_ready()):
		return
	
	if x < 0 or y < 0:
		return
	if y >= chunk_map.size() or x >= chunk_map.size():
		return
	var spos = Vector2i(x*CHUNK_SIZE,y*CHUNK_SIZE)
	if x > 0:
		spos = Vector2i((x*CHUNK_SIZE)-1,y*CHUNK_SIZE)
	if y > 0:
		spos = Vector2i(x*CHUNK_SIZE,(y*CHUNK_SIZE)-1)
	var sub_img = heightmap.get_region(Rect2i(spos,Vector2i(CHUNK_SIZE+1,CHUNK_SIZE+1)))
	chunk_map[y][x].load_map(sub_img)

#endregion


#region Place Objects


## object added
func add_world_object(obj):
	world_objects.push_back(obj)
	obj.delete.connect(remove_world_object.bind(obj))
	obj.preparing_to_select.connect(deselect_objects)


func remove_world_object(obj):
	world_objects.erase(obj)
	obj.queue_free()


func deselect_objects():
	for i in world_objects:
		i.selected = false


#endregion


#region Edit Mode Control Navigation

##Receive input from view edit button
func _change_view(id):
	cam_controller._switch_cam(id)


## Change edit mode
func _change_edit_mode(mode:String):
	match mode:
		"terrain":
			current_edit_mode = Edit_Mode.TERRAIN
		"place":
			current_edit_mode = Edit_Mode.OBJECTS
		"atmos":
			current_edit_mode = Edit_Mode.ATMOSPHERE
		"ground":
			current_edit_mode = Edit_Mode.GROUND



#endregion


#region Save/Load Map Functions

## Send Save request to off thread saver and hide menus 
func save_map():
	save_node.save_map()
	$UI/pause_menu.hide_pause_menu()
	$UI/save_menu.visible = false
	$UI/overwrite_menu.visible = false
	process_mode = Node.PROCESS_MODE_INHERIT


## Load Map file
func load_map(map_name: String):
	var dir : DirAccess
		
	## Set dir based on whether in build or editor debug
	if OS.has_feature("editor"):
		dir = DirAccess.open("user://")
	else:
		dir = DirAccess.open(OS.get_executable_path().get_base_dir())
	
	if (!dir.dir_exists("Assets/Levels/"+map_name)):
		## Cannot find level folder
		print("no such map")
		return
		
	## Level scene file
	var tmplvl = load(dir.get_current_dir()+"/Assets/Levels/"+map_name+"/level.tscn").instantiate()
	print("ground_texture_master_file")
	var ground_texture_master_file : Image = tmplvl.get_child(1).mesh.material.get_shader_parameter("grass_alb_tex").get_image()
	ground_texture_master_file.convert(Image.FORMAT_RGBA8)
	ground_texture_master_file.clear_mipmaps()
	
	await chunks_created
	## Parse ground texture
	## Default tex size is 2k x 2k
	for x in range(chunk_map.size()):
		for y in range(chunk_map.size()):
			chunk_map[y][x].set_ground_tex(ground_texture_master_file.get_region(Rect2i(x*2000,y*2000,2001,2001)))
	
	## Update level water tabel
	ui_node.water_level_slider_used(tmplvl.water_table)
	
	## Update level metdata and save menu data
	level_name = map_name
	$UI/save_menu/VBoxContainer/level_name.text = map_name
	level_year = tmplvl.year
	$UI/save_menu/VBoxContainer/start_date/year.text = str(level_year)
	level_year_day = tmplvl.year_day
	$UI/save_menu/VBoxContainer/start_date/OptionButton.selected = level_year_day/28
	$UI/save_menu/VBoxContainer/start_date/year3.text = str(tmplvl.year_day%28)
	level_uses_rnd_spawns = tmplvl.use_random_base_spawns
	$UI/save_menu/VBoxContainer/CheckBox.button_pressed = level_uses_rnd_spawns
	save_exists = true
	
	_change_edit_mode("place")
	## Load Objects into world starting after the moon on child position 8
	for nodes in range(8,tmplvl.get_children().size()):
		var node = tmplvl.get_child(nodes)
		## Check what node is
		if node is world_object:
			## if Node is a world object, add a world object container and edit accordingly
			var obj = load("res://World_Objects/Editor_Objects/world_object_edtor_container.tscn").instantiate()
			$level.add_child(obj)
			obj.load_node(node)
			obj.position = node.position
			world_objects.push_back(obj)
			obj.delete.connect(remove_world_object.bind(obj))
			continue
		if node is MeshInstance3D:
			## node is a decor item
			var obj = load("res://World_Objects/Editor_Objects/decor_editor.tscn").instantiate()
			$level.add_child(obj)
			obj.set_loaded_object()
			obj.preview_node = node.duplicate()
			obj.add_child(obj.preview_node)
			obj.position = node.position
			var v_displ = obj.position.y - obj.get_loc_height(obj.position,true)
			obj.preview_node.position = Vector3.ZERO
			obj.menu.load_values(v_displ)
			world_objects.push_back(obj)
			obj.delete.connect(remove_world_object.bind(obj))
			
	## Add Children of Base Spawns node and spawn base spawns from that
	for spawn in tmplvl.get_child(3).get_children():
		var obj = load("res://World_Objects/Editor_Objects/base_spawn_editor.tscn").instantiate()
		$level.add_child(obj)
		obj.set_loaded_object()
		obj.menu.set_player_id(spawn.actor_id)
		obj.position = spawn.position
		world_objects.push_back(obj)
		obj.delete.connect(remove_world_object.bind(obj))
	
	tmplvl.free()
	_change_edit_mode("terrain")


			
#endregion
