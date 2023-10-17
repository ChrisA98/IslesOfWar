extends MeshInstance3D

signal updated_map
signal neighbor_drawn_on

const MAX_HEIGHT = 2

var meshres = 2
var terrain_amplitude = 10
var chunk_x = 0
var chunk_y = 0

var chunk_heightmap_image : Image


@onready var level_builder_controller = get_parent().get_parent()

@onready var collision_mesh = get_node("StaticBody3D/CollisionShape3D")
@onready var collision_body = get_node("StaticBody3D")



func draw_brush_to_map(pos:Vector3, brush, size, strength: float):
	var local_pos = _convert_pos_to_local(pos)
	
	
	level_builder_controller.heightmap.flip_y()
	level_builder_controller.heightmap.rotate_90(CLOCKWISE)
	_draw_brush(local_pos,brush,strength)
	level_builder_controller.heightmap.rotate_90(COUNTERCLOCKWISE)
	level_builder_controller.heightmap.flip_y()
	
	## manage Update Signals
	level_builder_controller.update_chunk_tex(chunk_x,chunk_y)
	if local_pos.x + size > 500:
		neighbor_drawn_on.emit(chunk_x+1,chunk_y)
		if local_pos.y + size > 500:
			neighbor_drawn_on.emit(chunk_x+1,chunk_y+1)
			neighbor_drawn_on.emit(chunk_x,chunk_y+1)
	elif local_pos.y + size > 500:
		neighbor_drawn_on.emit(chunk_x,chunk_y+1)
		
	if local_pos.x - size < 0:
		neighbor_drawn_on.emit(chunk_x-1,chunk_y)
		if local_pos.y - size < 0:
			neighbor_drawn_on.emit(chunk_x-1,chunk_y-1)
			neighbor_drawn_on.emit(chunk_x,chunk_y-1)
	elif local_pos.y - size < 0:
		neighbor_drawn_on.emit(chunk_x,chunk_y-1)
	
	if local_pos.x- size < 0 and local_pos.y + size > 500:
		neighbor_drawn_on.emit(chunk_x-1,chunk_y+1)
	
	if local_pos.y - size < 0 and local_pos.x + size > 500:
		neighbor_drawn_on.emit(chunk_x+1,chunk_y-1)
		
	updated_map.emit()

func _draw_brush(pos,brush,strength):
	var brush_tex = brush.get_image()
	pos.x -= brush_tex.get_size().x/2
	pos.y -= brush_tex.get_size().y/2
	level_builder_controller.heightmap.blend_rect(brush_tex,Rect2i(0,0,512,512),pos)



func _draw_circle(pos,radius,strength):
	for x in range(radius*2.5):
		for y in range(radius*2.5):
			var v = Vector2i()
			v.x = pos.x-radius+x
			v.y = pos.y-radius+y
			var power = Vector2(v).distance_to(Vector2(pos.x,pos.y))/radius
			power = clamp(power,0,1)
			power = 1-power
			_draw_pixel(v,power,strength)
		

func _draw_pixel(pos,power,strength):
	pos.x += chunk_y * 500
	pos.y += chunk_x * 500
	if pos.x < 0 or pos.x >= level_builder_controller.map_size:
		return
	if pos.y < 0 or pos.y >= level_builder_controller.map_size:
		return
	var original_h = level_builder_controller.heightmap.get_pixelv(pos)
	var out_color = original_h + Color.WHITE*power*strength
	out_color.r = clamp(out_color.r,0,MAX_HEIGHT)
	out_color.g = clamp(out_color.g,0,MAX_HEIGHT)
	out_color.b = clamp(out_color.b,0,MAX_HEIGHT)
	level_builder_controller.heightmap.set_pixelv(pos,out_color)


## Get pixel coordiantes from global position
func _convert_pos_to_local(pos):
	var local_pos = pos
	local_pos.x += level_builder_controller.map_size/2
	local_pos.z += level_builder_controller.map_size/2
	local_pos.x = round(local_pos.x)
	local_pos.z = round(local_pos.z)
	return Vector2i(local_pos.z,local_pos.x)


func load_map(hm):
	chunk_heightmap_image = hm
	chunk_heightmap_image.flip_y()
	chunk_heightmap_image.rotate_90(CLOCKWISE)
	#_generate_collision_shape()


func _generate_collision_shape():
	var img = chunk_heightmap_image.duplicate(true)
	var hm = HeightMapShape3D.new()
	@warning_ignore("integer_division")
	var width = (50/meshres)+1
	@warning_ignore("integer_division")
	var height = (50/meshres)+1
	
	hm.set_map_width(width)
	hm.set_map_depth(height)
	
	var height_data = Array(hm.get_map_data())
	
	var id = 0
	for x in range(width):
		for y in range(height):
				height_data[id] = img.get_pixel(clamp(x*meshres*10,0,501),clamp(y*meshres*10,0,501)).r * terrain_amplitude
				id+=1
	collision_body.scale = Vector3(meshres*10,10,meshres*10)
	hm.set_map_data(PackedFloat32Array(height_data))
	collision_mesh.set_shape(hm)



func _debug_sphere(pos):
	var m = MeshInstance3D.new()
	m.mesh = SphereMesh.new()
	m.scale = Vector3(5,5,5)
	m.position = pos
	m.position.y += 5
	return m
