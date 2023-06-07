extends Node

@export var terrain_amplitude = 100
@export var water_table = 7

var rng = RandomNumberGenerator.new()
var height_data = {}
var vertices = PackedVector3Array()
var UVs = PackedVector2Array()
var normals = PackedVector3Array()
var chunks = 0
var chunk_size = 0

var meshres = 1

@onready var noise_image: Image = Image.new()
@export_dir var map_sections_path: String = "res://Test_Items/Map_data/" 
@onready var world_width
@onready var world_height
@onready var heightmap_chunk_size = 500


func _ready():
	var dir = DirAccess.open("res://Test_Items/Map_data/")
	noise_image.load("res://Test_Items/HeightMap.exr")
	world_width = noise_image.get_width()
	world_height = noise_image.get_height()
	create_chunks(noise_image)
	## Prepare chucnks
	for y in range(0,(world_height / heightmap_chunk_size)):
		for x in range(0,(world_height / heightmap_chunk_size)):
			var img = Image.new()
			var _img = load(map_sections_path+"chunk_"+str(y)+"_"+str(x)+".exr")
			img = _img.get_image()
			chunk_size = img.get_width()
			build_map(img, map_sections_path+"chunk_"+str(y)+"_"+str(x)+".tscn")
	get_tree().quit()


func build_map(img, path):
	var out = create_mesh(img)
	if ResourceSaver.save(out,path,ResourceSaver.FLAG_COMPRESS) != OK:
		print("ERROR")
	


func create_chunks(img: Image):
	for y in range(0,(world_height / heightmap_chunk_size)):
		for x in range(0,(world_width / heightmap_chunk_size)):
			var spos = Vector2i(x*heightmap_chunk_size,y*heightmap_chunk_size)
			if x > 0:
				spos = Vector2i((x*heightmap_chunk_size)-1,y*heightmap_chunk_size)
			if y > 0:
				spos = Vector2i(x*heightmap_chunk_size,(y*heightmap_chunk_size)-1)
			var sub_img = img.get_region(Rect2i(spos,Vector2i(heightmap_chunk_size+1,heightmap_chunk_size+1)))
			
			var out = (map_sections_path+"chunk_" + str(y)+"_"+str(x)+".exr")
			sub_img.save_exr(out)


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
					if(height_data[Vector2(x,y)] < water_table-1):
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
