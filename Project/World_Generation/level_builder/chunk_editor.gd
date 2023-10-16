extends MeshInstance3D

var meshres = 10
var terrain_amplitude = 10

var heightmap_image : Image

@onready var collision_mesh = get_node("StaticBody3D/CollisionShape3D")
@onready var collision_body = get_node("StaticBody3D")


func _input(event):
	if event.is_action_pressed("editor_cam_ascend"):
		collision_mesh.set_shape(_update_collision_shape())


func update_map(pos:Vector3, brush, strength: float):
	var local_pos = _convert_pos_to_local(pos)
	_draw_circle(local_pos,100,1)
	
	print(pos)
	print(local_pos)


func _draw_circle(pos,radius,str):
	for x in range(radius*2):
		for y in range(radius*2):
			var v = Vector2i()
			v.x = pos.x-radius+x
			v.y = pos.y-radius+y
			var pow = Vector2(v).distance_to(Vector2(pos.x,pos.y))/radius
			heightmap_image.set_pixelv(v,Color.WHITE*pow*str)
	

## Get pixel coordiantes from global position
func _convert_pos_to_local(pos):
	var local_pos = pos
	local_pos.x -= global_position.x
	local_pos.z -= global_position.z
	local_pos.x -= get_parent().position.x
	local_pos.z -= get_parent().position.z
	collision_mesh.set_shape(_update_collision_shape())
	local_pos.x = round(local_pos.x)
	local_pos.z = round(local_pos.z)
	return Vector2i(local_pos.x,local_pos.z)


func load_map(hm):
	heightmap_image = hm.get_image()
	heightmap_image.flip_y()
	heightmap_image.rotate_90(CLOCKWISE)
	collision_mesh.set_shape(_update_collision_shape())
	

func _update_collision_shape():
	var img = heightmap_image.duplicate(true)
	var hm = HeightMapShape3D.new()
	var width = 51
	var height = 51
	
	hm.set_map_width(51)
	hm.set_map_depth(51)
	
	var height_data = Array(hm.get_map_data())
	
	var id = 0
	for x in range(width):
		for y in range(height):
				height_data[id] = img.get_pixel(clamp(x*10,0,501),clamp(y*10,0,501)).r * terrain_amplitude
				id+=1
		
	hm.set_map_data(PackedFloat32Array(height_data))
	return hm

func _debug_sphere(pos):
	var m = MeshInstance3D.new()
	m.mesh = SphereMesh.new()
	m.scale = Vector3(5,5,5)
	m.position = pos
	m.position.y += 5
	return m
