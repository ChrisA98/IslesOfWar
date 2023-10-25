extends MeshInstance3D

signal updated_map
signal neighbor_drawn_on

const MAX_HEIGHT = 2

var brush_callable = Callable(_draw_brush)

var meshres = 10
var terrain_amplitude = 100
var chunk_x = 0
var chunk_y = 0

var width = 500
var height = 500
var gen_section = [0,25]
var gen_id = 0
var cycle = 0

var chunk_heightmap_image : Image

@onready var level_builder_controller = get_parent().get_parent()
@onready var collision_mesh = get_node("StaticBody3D/CollisionShape3D")
@onready var collision_body = get_node("StaticBody3D")


func draw_brush_to_map(pos:Vector3, brush, size):
	var local_pos = _convert_pos_to_local(pos)
	
	level_builder_controller.heightmap.flip_y()
	level_builder_controller.heightmap.rotate_90(CLOCKWISE)
	brush_callable.call(local_pos,brush)
	level_builder_controller.heightmap.rotate_90(COUNTERCLOCKWISE)
	level_builder_controller.heightmap.flip_y()
	
	## Manage Update Signals
	updated_map.emit()


func _draw_brush(pos,brush):
	var brush_tex = brush.get_image()
	var size = brush_tex.get_size().x
	pos.x -= brush_tex.get_size().x/2
	pos.y -= brush_tex.get_size().y/2
	level_builder_controller.heightmap.blend_rect_mask(brush_tex,brush_tex,Rect2i(0,0,size,size),pos)


## Smoothing Brush paints from average samplesd
func _smooth_brush(pos,brush):
	var brush_tex = brush.get_image()
	var size = brush_tex.get_size().x
	var str = brush_tex.get_pixel(size/2,size/2).a
	pos.x -= brush_tex.get_size().x/2
	pos.y -= brush_tex.get_size().y/2
	var sample_img = level_builder_controller.heightmap.get_region(Rect2i(pos.x,pos.y,size,size))
	var fill_color = _get_avg_color(sample_img)
	var fill_mean = Image.create(size,size,false,Image.FORMAT_RGBA8)
	fill_mean.fill(Color(fill_color,fill_color,fill_color,str))
	level_builder_controller.heightmap.blend_rect_mask(fill_mean,brush_tex,Rect2i(0,0,size,size),pos)


## Get approximate average of sample image
func _get_avg_color(img):
	var size = img.get_size().x
	var tot = 0
	var cnt = 0
	for x in range(size/10):
		for y in range(size/10):
			cnt += 1
			tot += img.get_pixel(x*10,y*10).r
	return tot/cnt


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
	_generate_collision_shape()


func _generate_collision_shape():
	var img = chunk_heightmap_image.duplicate(true)
	var hm = HeightMapShape3D.new()
	@warning_ignore("integer_division")
	width = (500/meshres)+1
	@warning_ignore("integer_division")
	height = (500/meshres)+1
	
	hm.set_map_width(width)
	hm.set_map_depth(height)
	
	var height_data = Array(hm.get_map_data())
	
	var id = 0
	for x in range(width):
		for y in range(height):
				height_data[id] = img.get_pixel(clamp(x*meshres,0,501),clamp(y*meshres,0,501)).r * terrain_amplitude/meshres
				id+=1
	collision_body.scale = Vector3(meshres,meshres,meshres)
	hm.set_map_data(PackedFloat32Array(height_data))
	collision_mesh.set_shape(hm)


## Set brush function
func _change_brush_function(id):
	match id:
		0:
			## Draw Brush
			brush_callable = Callable(_draw_brush)
		1:
			## Smooth Brush
			brush_callable = Callable(_smooth_brush)
		_:
			pass
