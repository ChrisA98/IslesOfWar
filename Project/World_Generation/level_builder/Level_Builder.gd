extends Node3D

signal brush_changed

const CHUNK_SIZE = 500

enum Edit_Mode {TERRAIN,OBJECTS,ATMOSPHERE,GROUND}

@export_range(500,10000,500) var map_size = 1000
@export var default_map_path : String

var heightmap: Image
var chunk_map =[]

var current_edit_mode : Edit_Mode = Edit_Mode.TERRAIN:
	set(value):
		current_edit_mode = value
		match current_edit_mode:
			Edit_Mode.TERRAIN:
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
				cursor.visible = false
				Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
			Edit_Mode.GROUND:
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

## Placed object arrays
var world_objects := []
var object_update_cycle: int

## Terrain texture array
var terrain_textures : Dictionary

@onready var ground_prev = get_node("visual_ground")
@onready var cursor = get_node("editor_cursor")
@onready var cam_controller = get_node("Editor_Cam")
@onready var ui_node = get_node("UI")
@onready var process_function = Callable(_terrain_process)
@onready var phys_process_function = Callable(_terrain_phys_process)
@onready var ground_click_func = Callable(_click_terrain_brush)


func _ready():
	#RenderingServer.global_shader_parameter_set("ground_tex_main",ImageTexture.create_from_image($UI/TextureRect.texture))
	_load_main_heightmap()
	call_deferred("_populate_chunks")
	_update_heightmap_master()
	
	ui_node.edit_mode_changed.connect(_change_edit_mode)
	
	## Set Blank texture to global shader variable so Trees can render
	var img = Image.create(map_size,map_size,false,Image.FORMAT_RGBF)
	img.fill(Color(0,0,0,0))
	RenderingServer.global_shader_parameter_set("building_locs",ImageTexture.create_from_image(img))
	
	#Load textures for terrain brush
	load_textures()
	

func _process(_delta):
	cursor.position = mouse_position
	process_function.call()


func _physics_process(_delta):
	phys_process_function.call()


## Set last brush stroke to undo cache
func _push_undo():
	if(undo_cache.size() > undo_max_size):
		undo_cache.pop_front()
	undo_cache.push_back([mouse_position,cursor.get_draw_tex(),cursor.radius])

#region Load Data Functions

## Create initial map
func _load_main_heightmap(_def = null):
	heightmap = Image.create(map_size,map_size,false,Image.FORMAT_RGBA8)
	heightmap.fill(Color(.1,.1,.1,1))
	_update_heightmap_master()
	#heightmap = load(default_map_path+"/master.exr").get_image()


## Create a noise generated Heightmap randomly
func _generate_random_heightmap():
	var random_noise = NoiseTexture2D.new()
	random_noise.set_width(map_size)
	random_noise.set_height(map_size)
	random_noise.noise = FastNoiseLite.new()
	random_noise.noise.seed = randi()
	random_noise.noise.frequency = 0.001
	random_noise.noise.domain_warp_enabled = true
	random_noise.noise.set_domain_warp_fractal_gain(.1)
	random_noise.noise.set_domain_warp_frequency (.002)
	await random_noise.changed
	heightmap = random_noise.get_image()
	heightmap.convert(5)
	_update_heightmap_master()


## Load Textures for terrain painting brush
func load_textures():
	var dir = DirAccess.open("res://Assets/Terrain_Textures/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var display_name = file_name.split(".")[0].replace("_"," ")
			terrain_textures[display_name] = load("res://Assets/Terrain_Textures/"+file_name)
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
			
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		save_map("test")
	
	update_cycle_y += 1
	if update_cycle_y >= chunk_map.size():
		update_cycle_x +=1
		update_cycle_y = 0
		if update_cycle_x >= chunk_map.size():
			update_cycle_x = 0


## place object process function
func _object_process():
	if object_update_cycle >= world_objects.size():
		object_update_cycle = 0
	if world_objects.size() == 0:
		return
	world_objects[object_update_cycle].update_node()
	object_update_cycle += 1

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
			new_chunk.mesh = chunk_template.mesh.duplicate(true)
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


#region Save Functions

## Create a level scene from the data in the curent scene
func save_map(level_name):
	## Create Scene from bas scene file
	var level_out_scene = load("res://World_Generation/base_level.tscn").instantiate()
	
	var dir = DirAccess.open("res://")
	
	if (!dir.dir_exists("Assets/Levels/"+level_name+"/")):
		dir.make_dir("Assets/Levels/"+level_name+"/")
	
	_store_heightmap("res://Assets/Levels/"+level_name+"/")
	
	## Transfer Basic Map Data
	level_out_scene.set_ground_tex(ImageTexture.create_from_image(_create_out_texture()))
	level_out_scene.heightmap_dir = "res://Assets/Levels/"+level_name+"/"
	level_out_scene.water_table = ui_node.water_level
	
	## Pack and Save Scene
	var packed_scene: PackedScene = PackedScene.new()
	packed_scene.pack(level_out_scene)
	## NOTE: temporary save path
	ResourceSaver.save(packed_scene,"res://Assets/Levels/"+level_name+"/level.scn",ResourceSaver.FLAG_COMPRESS)
	

## Bake ground textures to a master texture file
## NOTE: 2000x2000 is the base texture size
func _create_out_texture() -> Image:
	## Base Texture to write to
	var groundImage = Image.create(2000*chunk_map.size(),2000*chunk_map.size(),true,Image.FORMAT_RGBA8)
	
	
	## Stitch all ground textures together
	for x in range(chunk_map.size()):
		for y in range(chunk_map.size()):
			groundImage.blend_rect(chunk_map[x][y].ground_tex,Rect2i(0,0,2000,2000),Vector2i(y*2000,x*2000))
	
	groundImage.generate_mipmaps()
	
	return groundImage


func _store_heightmap(filepath:String):
	## Save master file
	heightmap.save_exr(filepath+"/master.exr")
	
	var chunk_image: Image
	## Split heightmap textures
	for x in range(chunk_map.size()):
		for y in range(chunk_map.size()):
			chunk_image = heightmap.get_region(Rect2i(x*500-x,y*500-y,501,501))
			chunk_image.save_exr(filepath+"/chunk_"+str(y)+"_"+str(x)+".exr")
			
#endregion
