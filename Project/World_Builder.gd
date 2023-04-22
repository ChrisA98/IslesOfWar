extends Node

@onready var noise_image: Image = Image.new()
@export_dir var map_sections_path: String = "res://Test_Items/Map_data/" 
@onready var world_width
@onready var world_height
@onready var heightmap_chunk_size = 500

var height_data = {}

@export var terrain_amplitude = 36

var vertices = PackedVector3Array()
var UVs = PackedVector2Array()
var normals = PackedVector3Array()

@onready var themesh = Mesh.new()
@onready var meshres = 1
@onready var mesh_container = self

func _ready():
	noise_image.load("res://Test_Items/HeightMap.exr")
	world_width = noise_image.get_width()
	world_height = noise_image.get_height()
	create_chunks(noise_image)
	get_tree().quit()

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
