extends Node3D


const CHUNK_SIZE = 500

@export_range(500,10000,500) var map_size = 1000
@export var default_map_path : String

var heightmap
var chunk_map =[]
var refresh_rate = 3
var refresh_counter = 5

## Cursor info
var mouse_position
var active_chunk

@onready var ground_prev = get_node("visual_ground")
@onready var cursor = get_node("editor_cursor")

func _ready():
	_load_main_heightmap()
	_populate_chunks()
	@warning_ignore("integer_division")
	$Editor_Cam.world_bounds = Vector2i(map_size/2,map_size/2)


func _process(_delta):
	refresh_counter -= 1
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if refresh_counter <= 0:
			refresh_counter = refresh_rate
			active_chunk.draw_brush_to_map(mouse_position,cursor.draw_tex,100,.1)
			return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if refresh_counter <= 0:
			refresh_counter = refresh_rate
			active_chunk.draw_brush_to_map(mouse_position,cursor.erase_tex,100, -1)
			return


func _load_main_heightmap(def = null):
	heightmap = Image.create(map_size,map_size,false,Image.FORMAT_RGBA8)
	heightmap.fill(Color(.1,.1,.1,1))
	_update_heightmap_master()
	#heightmap = load(default_map_path+"/master.exr").get_image()


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
			row.push_back(new_chunk)
		chunk_map.push_back(row)
	create_chunks()
	@warning_ignore("integer_division")
	ground_prev.position.x -= (CHUNK_SIZE*(chunks-1))/2
	@warning_ignore("integer_division")
	ground_prev.position.z -= (CHUNK_SIZE*(chunks-1))/2
	chunk_template.queue_free()


## Ground Shape interacted with
func ground_click(_camera, _event:InputEvent, pos:Vector3, _normal, _shape_idx, chunk):
	cursor.position = pos
	mouse_position = pos
	active_chunk = chunk


func _update_heightmap_master():
	var hm_tex = ImageTexture.create_from_image(heightmap)
	RenderingServer.global_shader_parameter_set("heightmap_tex",hm_tex)
	RenderingServer.global_shader_parameter_set("heightmap_tex_size",Vector2(map_size,map_size))


## Generate all chunk textures
func create_chunks():
	for y in range(0,(map_size / CHUNK_SIZE)):
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

	
