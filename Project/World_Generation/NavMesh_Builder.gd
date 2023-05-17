extends Node3D

@onready var gamescene = $".."

@onready var noise_image: Image = Image.new()
@onready var chunk_size = 500
@onready var nav_manager = preload("res://World_Generation/NavMeshManager.gd")
@export var heightmap_dir: String = "res://Test_Items/Map_data/"

## Level terrain info
@export var water_table : float = 7
@onready var ground = get_node("Visual_Ground")
@onready var water = get_node("Water")


var height_data = {}

@export var terrain_amplitude = 100

var vertices = PackedVector3Array()
var UVs = PackedVector2Array()
var normals = PackedVector3Array()

@onready var meshres = 5


func _ready():
	var chunks = sqrt(find_files())
	
	## Prepare chucnks
	for y in range(0,chunks):
		for x in range(0,chunks):
			var img = Image.new()
			var _img = load(heightmap_dir+"chunk_"+str(y)+"_"+str(x)+".exr")
			img = _img.get_image()
			chunk_size = img.get_width()
			build_map(img, Vector3(x-1,0,y),Vector2i(x,y))
	
	## Assign Regions to terrain mesh chunks
	for i in get_children():
		if i.name.contains("Region"):
			i.get_child(0).get_child(0).input_event.connect(gamescene.ground_click.bind(i)) 
			i.get_child(0).transparency = 1 #hide terrain mesh
			i.get_child(0).get_child(0).set_collision_layer_value(16,true)
			i.get_child(0).get_child(0).set_collision_mask_value(16,true)
			i.get_child(0).get_child(0).set_meta("is_ground", true)
			i.set_nav_region()
	
	## Prepare Ground with level info
	ground.mesh.surface_get_material(0).set_shader_parameter("water_table", water_table)
	ground.mesh.surface_get_material(0).set_shader_parameter("max_sand_height", water_table+2)
	ground.mesh.surface_get_material(0).set_shader_parameter("t_height", terrain_amplitude)
	## Prepare Water with level info
	water.position.y = water_table
	water.mesh.surface_get_material(0).set_shader_parameter("water_level", water_table)
	water.mesh.surface_get_material(0).set_shader_parameter("t_height", terrain_amplitude)


#check if .exr files exist in target path
func find_files():
	var dir = DirAccess.open(heightmap_dir)
	var cnt = 0
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.get_extension() == "exr":
				cnt+=1
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	return cnt


func update_navigation_meshes(grp):
	var targ = "Region"
	if(grp != null):
		targ += grp.get_slice("g",1)
	for i in get_children():
		if i.name.contains(targ):
			i.update_navigation_mesh()


func build_map(img, pos, adj):	
	var grp = StringName("reg_"+str(adj.x) +"_"+ str(adj.y))
	#build nav region for chunk
	var chunk_nav_region = NavigationRegion3D.new()
	chunk_nav_region.set_script(nav_manager)
	chunk_nav_region.add_to_group(grp)
	#build mesh for chunk
	var mesh = MeshInstance3D.new()
	mesh.set_mesh(create_mesh(img))
	mesh.set_name("Floor")
	#add to world
	add_child(chunk_nav_region)
	get_child(-1).set_name("Region_"+str(adj.x) +"_"+ str(adj.y))
	chunk_nav_region.add_child(mesh)
	mesh.create_trimesh_collision()
	mesh.add_to_group(grp)
	
	mesh.position = pos*chunk_size - Vector3(adj.x,0,adj.y)
	
	var scale_ratio = chunk_size / float(img.get_width())
	mesh.scale *= scale_ratio


func create_mesh(img):
	var st = ImmediateMesh.new()
	st.clear_surfaces()
	var width = img.get_width()
	var height = img.get_height()	
	img.flip_y()
	
	vertices.resize(0)
	UVs.resize(0)
	normals.resize(0)
	
	var heightmap = img
	
	for x in range(width):
		if x % meshres == 0:
			for y in range(height):
				if y % meshres == 0:
					height_data[Vector2(x,y)] = heightmap.get_pixel(x,y).r * terrain_amplitude
		
	
	for x in height_data:
		if (x.x<width-meshres and x.y<height-meshres):
			createQuad(x.x,x.y)
	st.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for v in vertices.size():
		st.surface_set_uv(UVs[v])
		st.surface_set_normal(normals[v])
		st.surface_add_vertex(vertices[v])
	st.surface_end()
	return st


func createQuad(x,y):	
	var vert1
	var vert2
	var vert3
	var side1
	var side2
	var normal
	
	vert1 = Vector3(x,height_data[Vector2(x,y)],-y)
	vert2 = Vector3(x,height_data[Vector2(x,y+meshres)], -y-meshres)
	vert3 = Vector3(x+meshres, height_data[Vector2(x+meshres,y+meshres)],-y-meshres)
	vertices.push_back(vert1)
	vertices.push_back(vert2)
	vertices.push_back(vert3)
	
	UVs.push_back(Vector2(vert1.x, -vert1.z))
	UVs.push_back(Vector2(vert2.x, -vert2.z))
	UVs.push_back(Vector2(vert3.x, -vert3.z))
	
	side1 = vert2-vert1
	side2 = vert2-vert3
	normal = side1.cross(side2)
	
	for i in range(0,3):
		normals.push_back(normal)
	
	vert1 = Vector3(x,height_data[Vector2(x,y)],-y)
	vert2 = Vector3(x+meshres, height_data[Vector2(x+meshres,y+meshres)], -y-meshres)
	vert3 = Vector3(x+meshres, height_data[Vector2(x+meshres,y)],-y)
	vertices.push_back(vert1)
	vertices.push_back(vert2)
	vertices.push_back(vert3)
	
	UVs.push_back(Vector2(vert1.x, -vert1.z))
	UVs.push_back(Vector2(vert2.x, -vert2.z))
	UVs.push_back(Vector2(vert3.x, -vert3.z))
	
	side1 = vert2-vert1
	side2 = vert2-vert3
	normal = side1.cross(side2)
	
	for i in range(0,3):
		normals.push_back(normal)


func get_region(pos : Vector3):
	return StringName("reg_"+str(int(pos.x/chunk_size)) +"_"+ str(int(pos.z/chunk_size)))
