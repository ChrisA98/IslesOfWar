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

var heightmap

@onready var noise_image: Image = Image.new()
@export_dir var map_sections_path: String = "res://Test_Items/Map_data/" 
@onready var world_width
@onready var world_height
@onready var heightmap_chunk_size = 500


func _ready():
	noise_image.load("res://Test_Items/HeightMap.exr")
	world_width = noise_image.get_width()
	world_height = noise_image.get_height()
	create_chunks(noise_image)
	## Prepare chunks
	for y in range(0,(world_height / heightmap_chunk_size)):
		for x in range(0,(world_height / heightmap_chunk_size)):
			var _img = Image.new()
			var __img = load(map_sections_path+"chunk_"+str(y)+"_"+str(x)+".exr")
			_img = __img.get_image()
			chunk_size = _img.get_width()
			_create_heightmap(_img, map_sections_path+"chunk_"+str(y)+"_"+str(x)+".tres")
	get_tree().quit()


## Create chunk for heightmap images
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


func _create_heightmap(img,path):
	var hm = HeightMapShape3D.new()
	var width = img.get_width()
	var height = img.get_height()	
	img.flip_y()
	var data = []
	
	hm.map_width = width
	hm.map_depth = height
	
	for x in range(width):
		if x % meshres == 0:
			for y in range(height):
				if y % meshres == 0:
					if(img.get_pixel(x,y).r * terrain_amplitude < water_table):
						data.push_back(-10000)
					else:
						data.push_back(img.get_pixel(x,y).r * terrain_amplitude)
	
	hm.map_data = PackedFloat32Array(data)
	$StaticBody3D/CollisionShape3D.shape = hm
	
	print(path)
	if ResourceSaver.save(hm,path) != OK:
		print("ERROR")


