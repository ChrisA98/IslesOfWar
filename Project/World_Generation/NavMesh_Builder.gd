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
var heightmap


var rng = RandomNumberGenerator.new()
var height_data = {}

@export var terrain_amplitude = 100

var vertices = PackedVector3Array()
var UVs = PackedVector2Array()
var normals = PackedVector3Array()

@onready var meshres = 5


func _ready():
	var chunks = sqrt(find_files())
	heightmap = load(heightmap_dir+"master"+".exr").get_image()
	
	## Prepare chunks
	for y in range(0,chunks):
		for x in range(0,chunks):
			var _img = Image.new()
			var __img = load(heightmap_dir+"chunk_"+str(y)+"_"+str(x)+".exr")
			_img = __img.get_image()
			chunk_size = _img.get_width()
			build_map(_img, Vector3(x-1,0,y),Vector2i(x,y))
	
	## Assign Regions to terrain mesh chunks
	for i in get_children():
		if i.name.contains("Region"):
			i.get_child(0).get_child(0).input_event.connect(gamescene.ground_click.bind(i)) 
			i.get_child(0).transparency = 1 #hide terrain mesh
			i.get_child(0).get_child(0).set_collision_layer_value(16,true)
			i.get_child(0).get_child(0).set_collision_mask_value(16,true)
			i.get_child(0).get_child(0).set_meta("is_ground", true)
			i.set_nav_region()
	
	
	$Water/StaticBody3D.input_event.connect(gamescene.ground_click.bind($Water/StaticBody3D)) 
	
	var wtr_nav_region = NavigationRegion3D.new()
	wtr_nav_region.set_script(nav_manager)
	wtr_nav_region.agent_max_slope = 10
	wtr_nav_region.agent_radius = 10
	wtr_nav_region.add_to_group("water")
	#add to world
	add_child(wtr_nav_region)
	get_child(-1).set_name("water_navigation")	
	wtr_nav_region.set_nav_region()
	wtr_nav_region.navigation_mesh.set_filter_baking_aabb(AABB(Vector3(-chunk_size,-1.9,-chunk_size),Vector3(chunks*chunk_size,10,chunks*chunk_size)))
	wtr_nav_region.enter_cost = 1000
	wtr_nav_region.update_navigation_mesh()
	wtr_nav_region.set_navigation_layer_value(1, false)
	wtr_nav_region.set_navigation_layer_value(2, true)
	
	## Prepare Ground with level info
	ground.mesh.surface_get_material(0).set_shader_parameter("water_table", water_table)
	ground.mesh.surface_get_material(0).set_shader_parameter("max_sand_height", water_table+2)
	ground.mesh.surface_get_material(0).set_shader_parameter("t_height", terrain_amplitude)
	## Prepare Water with level info
	water.position.y = water_table
	water.mesh.surface_get_material(0).set_shader_parameter("water_level", water_table)
	water.mesh.surface_get_material(0).set_shader_parameter("t_height", terrain_amplitude)
	
	## Fog of war walls
	var fog_wall_size = ((chunk_size*chunks)/65)+1	#gets length of walls
	var base_fog_wall = $Great_Fog_Wall.find_children("Fog*","Node",false)[-1]
	base_fog_wall.position.x = ((chunk_size*chunks)/2) + 65
	base_fog_wall.position.z = ((chunk_size*chunks*-1)/2) - 65
	for j in range(fog_wall_size):
		var te = base_fog_wall.duplicate()
		te.position.x -= 65*j
		$Great_Fog_Wall.add_child(te)
	for j in range(fog_wall_size):
		var te = base_fog_wall.duplicate()
		te.position.z += 65*j
		$Great_Fog_Wall.add_child(te)
	for j in range(fog_wall_size+1):
		var te = base_fog_wall.duplicate()
		te.position.x -= 65*j
		te.position.z = 555
		$Great_Fog_Wall.add_child(te)
	for j in range(fog_wall_size+1):
		var te = base_fog_wall.duplicate()
		te.position.z += 65*j
		te.position.x = -555
		$Great_Fog_Wall.add_child(te)
	call_deferred("build_fog_war",chunks)
	


func build_fog_war(chunks):
	await get_tree().physics_frame
	
	## Fog of explorable
	var fog_explor_range = (chunk_size*chunks)/25	#gets length of walls
	var base_fog = $Explorable_Fog.find_children("Fog*","Node",false)[-1]
	base_fog.position.x = ((chunk_size*chunks)/2) - 25
	base_fog.position.z = ((chunk_size*chunks*-1)/2) + 25
	var picker  = $Explorable_Fog/RayCast3D
	for i in range(fog_explor_range):
		for j in range(fog_explor_range):
			var te = base_fog.duplicate()
			te.position.x -= 25*j
			te.position.z += 25*i
			picker.position.x = te.position.x
			picker.position.z = te.position.z 
			picker.force_raycast_update()
			te.position.y = picker.get_collision_point().y
			$Explorable_Fog.add_child(te)


#check if .exr files exist in target path
func find_files():
	var dir = DirAccess.open(heightmap_dir)
	var cnt = -1
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
	mesh.add_to_group("water")
	
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
	
	var _heightmap = img
	
	for x in range(width):
		if x % meshres == 0:
			for y in range(height):
				if y % meshres == 0:
					height_data[Vector2(x,y)] = _heightmap.get_pixel(x,y).r * terrain_amplitude
					if(height_data[Vector2(x,y)] < water_table):
						height_data[Vector2(x,y)] -= (100 + rng.randf_range(10,50))
		
	
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
