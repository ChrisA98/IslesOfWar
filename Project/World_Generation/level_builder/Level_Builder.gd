extends Node3D


const CHUNK_SIZE = 500

@export_range(500,10000,500) var map_size = 1000
@export var default_map_path : String

var heightmap

@onready var ground_prev = get_node("visual_ground")
@onready var cursor = get_node("editor_cursor")

func _ready():
	_populate_chunks()
	@warning_ignore("integer_division")
	$Editor_Cam.world_bounds = Vector2i(map_size/2,map_size/2)


func _load_main_heightmap():
	heightmap = load(default_map_path+"/master.exr").get_image()


func _populate_chunks():
	@warning_ignore("integer_division")
	var chunks = map_size/CHUNK_SIZE
	
	var chunk_template = $chunk
	
	for y in range(chunks):
		for x in range(chunks):
			var new_chunk = chunk_template.duplicate()
			new_chunk.position.x = x*CHUNK_SIZE
			new_chunk.position.z = y*CHUNK_SIZE
			new_chunk.name = "chunk_"+str(y)+"_"+str(x)
			var file_path = default_map_path+"/chunk_"+str(y)+"_"+str(x)+".exr"
			ground_prev.add_child(new_chunk)
			new_chunk.load_map(load(file_path))
			new_chunk.collision_body.input_event.connect(ground_click.bind(new_chunk))
	@warning_ignore("integer_division")
	ground_prev.position.x -= (CHUNK_SIZE*(chunks-1))/2
	ground_prev.position.z -= (CHUNK_SIZE*(chunks-1))/2
	chunk_template.queue_free()


## Ground Shape clicked
func ground_click(camera, event:InputEvent, pos:Vector3, _normal, _shape_idx, chunk):
	cursor.position = pos
	if event.is_action_pressed("lmb"):
		print(chunk.name)
		chunk.update_map(pos,cursor.texture_albedo,1)
