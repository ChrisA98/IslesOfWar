extends MeshInstance3D

signal updated_map
signal drawn_map
signal neighbor_drawn_on
signal initialized

const MAX_HEIGHT = 2

var brush_callable = Callable(_draw_brush)
var paint_callable = Callable()

var meshres = 10
var terrain_amplitude = 100
var chunk_x = 0
var chunk_y = 0

var width = 500
var height = 500

var chunk_heightmap_image : Image
var ground_tex : Image

# Create a local rendering device.
var rd := RenderingServer.create_local_rendering_device()

# Load GLSL shader
@onready var shader_file = preload("res://Test_Items/test_compute.glsl")
var shader_spirv: RDShaderSPIRV 
var shader: RID
var pipeline: RID
var paint_tex_rid: RID
var brush_rid: RID
var uniform_set: RID

var tex_format
var stored_mask_data : PackedByteArray
var stored_paint_data : PackedByteArray

@onready var level_builder_controller = get_parent().get_parent()
@onready var collision_mesh = get_node("StaticBody3D/CollisionShape3D")
@onready var collision_body = get_node("StaticBody3D")


func load_ground_tex():
	ground_tex = mesh.material.get_shader_parameter("grass_alb_tex").get_image()
	_prepare_rendering_device()


func _prepare_rendering_device():
	await get_tree().physics_frame
	shader_spirv= shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	
	# Create format for the paint.
	tex_format = RDTextureFormat.new()
	# There are a lot of different formats. It might take some studying to be able to be able to
	# choose the right ones. In this case, we tell it to interpret the data as a single byte for red.
	# Even though the noise image only has a luminance channel, we can just interpret this as if it
	# was the red channel. The byte layout is the same!
	tex_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	tex_format.width = 1
	tex_format.height = 1
	# The TextureUsageBits are stored as 'bit field
	tex_format.usage_bits = \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	
	pipeline = rd.compute_pipeline_create(shader)

""" Paint Brush Interactions """



## Paint textures to terrain map
func paint_brush_to_terrain(pos:Vector3, brush: Image, tex: Image):
	var local_pos = _convert_pos_to_local(pos, tex.get_width())
	var _brush:Image = brush.duplicate()
	_brush.resize(brush.get_width()*2,brush.get_width()*2)
	## Resize Painted texture to stretch to ground texture size
	tex.resize(ground_tex.get_width(),ground_tex.get_width())
	
	_paint_brush(local_pos,_brush,tex)


func _paint_brush(pos,brush,tex:Image):
	var _tex = tex ## Texture copy of the painted ground
	var brush_tex = brush ## Brush mask
	var brush_size = brush_tex.get_width()
	
	## Get Rect region of new groun tex of size appropriate for the brush
	var paint = _tex.get_region(Rect2i(pos.x-brush_size/2,pos.y-brush_size/2,brush_size,brush_size))
	
	## Alpha blend the brush with Computational Shader
	paint = _get_blended_paint_brush(paint,brush_tex,brush_size)
	
	## NOTE: the -10 is to accomodate an artifact created from the computational shader
	ground_tex.blend_rect(paint,Rect2i(0,0,brush_size,brush_size-10),pos-Vector2i(brush_size/2,brush_size/2))
	
	var img = ImageTexture.create_from_image(ground_tex)
	mesh.material.set_shader_parameter("grass_alb_tex",img)
	_paint_to_neighbors(pos,brush_tex, _tex, ground_tex.get_width())


## Paint ground tex to neighbor chunks
func _paint_to_neighbors(pos, brush_tex, paint, size):
	var l_pos = pos ## Localized position
	var chunk_size = size ##Ground tex size
	var brush_size = brush_tex.get_width()/2 ## Brush Texture scale

	## Painting -x direction
	if pos.x - (brush_size/2) <= 0 and chunk_x !=0 :
		l_pos.x += chunk_size
		level_builder_controller.chunk_map[chunk_y][chunk_x-1].paint_from_neighbor(l_pos, brush_tex, paint)
		## && Painting -y direction
		if pos.y - (brush_size/2) <= 0 and chunk_y !=0 :
			l_pos.y += chunk_size
			level_builder_controller.chunk_map[chunk_y-1][chunk_x-1].paint_from_neighbor(l_pos, brush_tex, paint)
			l_pos.x -= chunk_size
			level_builder_controller.chunk_map[chunk_y-1][chunk_x].paint_from_neighbor(l_pos, brush_tex, paint)
			return
		## && Painting +y direction
		if pos.y + (brush_size) >= chunk_size/2 and level_builder_controller.chunk_map.size() > chunk_y+1 :
			l_pos.y -= chunk_size
			level_builder_controller.chunk_map[chunk_y+1][chunk_x-1].paint_from_neighbor(l_pos, brush_tex, paint)
			l_pos.x -= chunk_size
			level_builder_controller.chunk_map[chunk_y+1][chunk_x].paint_from_neighbor(l_pos, brush_tex, paint)
		return
	## Painting +x direction
	if pos.x + (brush_size/2) >= chunk_size/2 and level_builder_controller.chunk_map.size() > chunk_x+1:
		l_pos.x -= chunk_size
		level_builder_controller.chunk_map[chunk_y][chunk_x+1].paint_from_neighbor(l_pos, brush_tex, paint)
		## && Painting -y direction
		if pos.y - (brush_size/2) <= 0 and chunk_y !=0 :
			l_pos.y += chunk_size
			level_builder_controller.chunk_map[chunk_y-1][chunk_x+1].paint_from_neighbor(l_pos, brush_tex, paint)
			l_pos.x += chunk_size
			level_builder_controller.chunk_map[chunk_y-1][chunk_x].paint_from_neighbor(l_pos, brush_tex, paint)
			return
		## && Painting +y direction
		if pos.y + (brush_size) >= chunk_size/2 and level_builder_controller.chunk_map.size() > chunk_y+1 :
			l_pos.y -= chunk_size
			level_builder_controller.chunk_map[chunk_y+1][chunk_x+1].paint_from_neighbor(l_pos, brush_tex, paint)
			l_pos.x += chunk_size
			level_builder_controller.chunk_map[chunk_y+1][chunk_x].paint_from_neighbor(l_pos, brush_tex, paint)
		return		
	## Painting -y direction
	if pos.y - (brush_size/2) <= 0 and chunk_y !=0 :
		l_pos.y += chunk_size
		level_builder_controller.chunk_map[chunk_y-1][chunk_x].paint_from_neighbor(l_pos, brush_tex, paint)
		return
	## Painting +y direction
	if pos.y + (brush_size) >= chunk_size and level_builder_controller.chunk_map.size() > chunk_y+1 :
		l_pos.y -= chunk_size
		level_builder_controller.chunk_map[chunk_y+1][chunk_x].paint_from_neighbor(l_pos, brush_tex, paint)


func paint_from_neighbor(pos, brush_tex, pre_paint):
	
	var brush_size = brush_tex.get_width()
	
	## Get Rect region of new groun tex of size appropriate for the brush
	var paint = pre_paint.get_region(Rect2i(pos.x-brush_size/2,(pos.y-brush_size/2),brush_size,brush_size))
	
	## Alpha blend the brush with Computational Shader
	paint = _get_blended_paint_brush(paint,brush_tex,brush_size)
	
	ground_tex.blend_rect(paint,Rect2i(0,0,brush_size,brush_size-10),pos-Vector2i(brush_size/2,brush_size/2))
	
	var img = ImageTexture.create_from_image(ground_tex)
	mesh.material.set_shader_parameter("grass_alb_tex",img)


func _get_blended_paint_brush(paint,brush_tex,size):
	# Prepare our data. We use floats in the shader, so we need 32 bit.
	paint.clear_mipmaps()
	var mask_data = brush_tex.get_data()
	var paint_data = paint.get_data()	
	
	
	# Set uniform values
	if (tex_format.width != size):
		tex_format.width = paint.get_width()
		tex_format.height = paint.get_width()
		paint_tex_rid = rd.texture_create(tex_format, RDTextureView.new(),[paint_data])
		brush_rid = rd.texture_create(tex_format, RDTextureView.new(),[mask_data])
		stored_paint_data = paint_data
		stored_mask_data = mask_data
	else:
		rd.texture_update(paint_tex_rid, 0, paint_data)
		rd.texture_update(brush_rid, 0, mask_data)
		
	
	# Create uniform for paint.
	var paint_tex_uniform := RDUniform.new()
	paint_tex_uniform.set_uniform_type(RenderingDevice.UNIFORM_TYPE_IMAGE)
	paint_tex_uniform.binding = 1  # This matches the binding in the shader.
	paint_tex_uniform.add_id(paint_tex_rid)

	
	# Create uniform for brush.
	var brush_tex_uniform := RDUniform.new()
	brush_tex_uniform.set_uniform_type(RenderingDevice.UNIFORM_TYPE_IMAGE)
	brush_tex_uniform.binding = 0  # This matches the binding in the shader.
	brush_tex_uniform.add_id(brush_rid)

	uniform_set = rd.uniform_set_create([brush_tex_uniform,paint_tex_uniform], shader, 0)

	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	# This is where the magic happens! As our shader has a work group size of 8x8x1, we dispatch
	# one for every 8x8 block of pixels here. This ratio is highly tunable, and performance may vary.
	rd.compute_list_dispatch(compute_list, size / 8, size / 8, 1)
	rd.compute_list_end()
	
	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()
	
	var output_bytes := rd.texture_get_data(paint_tex_rid, 0)
	var out_image  := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, output_bytes)
		
	return out_image



""" Terrain Brush Interactions """



func draw_brush_to_map(pos:Vector3, brush, _size):
	var local_pos = _convert_pos_to_hm_local(pos)
	brush_callable.call(local_pos,brush)
	
	## Manage Update Signals
	updated_map.emit()


func _draw_brush(pos,brush):
	var brush_tex = brush.get_image()
	var size = brush_tex.get_size().x
	pos.x -= size/2
	pos.y -= size/2
	level_builder_controller.heightmap.blend_rect_mask(brush_tex,brush_tex,Rect2i(0,0,size,size),pos)


## Smoothing Brush paints from average samples
func _smooth_brush(pos,brush):
	var brush_tex = brush.get_image()
	var size = brush_tex.get_size().x
	var _str = brush_tex.get_pixel(size/2,size/2).a
	pos.x -= brush_tex.get_size().x/2
	pos.y -= brush_tex.get_size().y/2
	var sample_img = level_builder_controller.heightmap.get_region(Rect2i(pos.x,pos.y,size,size))
	var fill_color = _get_avg_color(sample_img)
	var fill_mean = Image.create(size,size,false,Image.FORMAT_RGBA8)
	fill_mean.fill(Color(fill_color,fill_color,fill_color,_str))
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
func _convert_pos_to_local(pos, img_scale):
	var local_pos = pos
	local_pos.x -= global_position.x-250
	local_pos.z -= global_position.z-250
	local_pos.x = round(local_pos.x/500*img_scale)
	local_pos.z = round(local_pos.z/500*img_scale)
	return Vector2i(local_pos.x,local_pos.z)


## Get pixel coordiantes from global position for heightmnap
func _convert_pos_to_hm_local(pos):
	var local_pos = pos
	@warning_ignore("integer_division")
	local_pos.x += Global_Vars.heightmap_size/2
	@warning_ignore("integer_division")
	local_pos.z += Global_Vars.heightmap_size/2
	local_pos.x = round(local_pos.x)
	local_pos.z = round(local_pos.z)
	return Vector2i(local_pos.x,local_pos.z)


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
