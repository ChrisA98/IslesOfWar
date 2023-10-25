extends Node3D

signal brush_changed

const CHUNK_SIZE = 500

enum Edit_Mode {TERRAIN,OBJECTS,ATMOSPHERE}

@export_range(500,10000,500) var map_size = 1000
@export var default_map_path : String

var heightmap
var chunk_map =[]

var current_edit_mode : Edit_Mode = Edit_Mode.TERRAIN:
	set(value):
		pass

## Cursor info
var mouse_held := false
var mouse_position : Vector3
var active_chunk

var update_cycle_x = 0
var update_cycle_y = 0

var undo_cache = []
var undo_max_size = 32000

@onready var ground_prev = get_node("visual_ground")
@onready var cursor = get_node("editor_cursor")
@onready var ui_node = get_node("UI")


func _ready():
	_load_main_heightmap()
	_populate_chunks()
	@warning_ignore("integer_division")
	$Editor_Cam.world_bounds = Vector2i(map_size/2,map_size/2)


func _process(_delta):
	cursor.position = mouse_position
	if mouse_held and !ui_node.mouse_used:
		active_chunk.draw_brush_to_map(mouse_position,cursor.get_draw_tex(),cursor.radius)
		_push_undo()
		if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			mouse_held = false


func _physics_process(_delta):
	if chunk_map.size() == 0:
		return
	
	update_cycle_y += 1
	if update_cycle_y >= chunk_map.size():
		update_cycle_x +=1
		update_cycle_y = 0
		if update_cycle_x >= chunk_map.size():
			update_cycle_x = 0
	
	update_chunk_tex(update_cycle_x,update_cycle_y)


## Set last brush stroke to undo cache
func _push_undo():
	if(undo_cache.size() > undo_max_size):
		undo_cache.pop_front()
	undo_cache.push_back([mouse_position,cursor.get_draw_tex(),cursor.radius])


## Create initial map
func _load_main_heightmap(_def = null):
	heightmap = Image.create(map_size,map_size,false,Image.FORMAT_RGBA8)
	heightmap.fill(Color(.1,.1,.1,1))
	_update_heightmap_master()
	#heightmap = load(default_map_path+"/master.exr").get_image()



""" Interact functions"""

## changed brush mode
func brush_mode_changed(id):
	brush_changed.emit(id)


## Ground Shape interacted with
func ground_click(_camera, event:InputEvent, pos:Vector3, _normal, _shape_idx, chunk):
	if (mouse_position - pos).length() < 400:
		mouse_position = pos
	active_chunk = chunk	
	if event is InputEventMouseButton:
		if event.button_index == 1:
			mouse_held = event.is_pressed()
			
	if event.is_action("ui_undo"):
		pass


func _entered_body():
	pass



""" Edit Chunks"""



## Create brushes at start of level
func _populate_chunks():
	@warning_ignore("integer_division")
	var chunks = map_size/CHUNK_SIZE
	
	var chunk_template = $chunk
	
	for y in range(chunks):
		var row = []
		for x in range(chunks):
			var new_chunk = chunk_template.duplicate()
			new_chunk.chunk_x = x
			new_chunk.chunk_y = y
			new_chunk.position.x = x*CHUNK_SIZE
			new_chunk.position.z = y*CHUNK_SIZE
			new_chunk.name = "chunk_"+str(y)+"_"+str(x)
			var file_path = default_map_path+"/chunk_"+str(y)+"_"+str(x)+".exr"
			ground_prev.add_child(new_chunk)
			#new_chunk.load_map(load(file_path).get_image())
			new_chunk.collision_body.input_event.connect(ground_click.bind(new_chunk))
			new_chunk.updated_map.connect(_update_heightmap_master)
			new_chunk.neighbor_drawn_on.connect(update_chunk_tex)
			brush_changed.connect(new_chunk._change_brush_function)
			row.push_back(new_chunk)
		chunk_map.push_back(row)
	create_chunks()
	@warning_ignore("integer_division")
	ground_prev.position.x -= (CHUNK_SIZE*(chunks-1))/2
	@warning_ignore("integer_division")
	ground_prev.position.z -= (CHUNK_SIZE*(chunks-1))/2
	chunk_template.queue_free()


func _update_heightmap_master():
	var hm_tex = ImageTexture.create_from_image(heightmap)
	RenderingServer.global_shader_parameter_set("heightmap_tex",hm_tex)
	RenderingServer.global_shader_parameter_set("heightmap_tex_size",Vector2(map_size,map_size))


## Generate all chunk textures
func create_chunks():
	@warning_ignore("integer_division")
	for y in range(0,(map_size / CHUNK_SIZE)):
		@warning_ignore("integer_division")
		for x in range(0,(map_size / CHUNK_SIZE)):
			update_chunk_tex(x,y)


## Get chunk of total heightmap and assign it to local chunk
func update_chunk_tex(x,y):
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



""" Edit Mode Control Navigation"""



## Change edit mode
func _change_edit_mode(mode:String):
	match mode:
		"terrain":
			current_edit_mode = Edit_Mode.TERRAIN
		"place":
			current_edit_mode = Edit_Mode.OBJECTS
		"atmos":
			current_edit_mode = Edit_Mode.ATMOSPHERE
