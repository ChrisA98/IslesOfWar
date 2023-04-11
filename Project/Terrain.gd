@tool
extends MeshInstance3D


@export var chunk_size = 2
@export var height_ratio = 1
@export var col_shape_size_ratio = .01

var img = Image.new()
var shape = HeightMapShape3D.new()


func _ready():
	mesh.size = Vector2(chunk_size, chunk_size)
	update_terrain(height_ratio, col_shape_size_ratio)


func update_terrain(_height_ratio, _col_shape_size_ratio):
	material_override.set("shader_param/height_ratio", _height_ratio)
	
	img.load("res://Test_Items/HeightMap.exr")
	img.convert(Image.FORMAT_RF)
	img.resize(img.get_width() * _col_shape_size_ratio, img.get_height() * _col_shape_size_ratio)
	
	var data = img.get_data().to_float32_array()
	
	for i in range(0, data.size()):
		data[i] *= _height_ratio
	
	shape.map_width = img.get_width()
	shape.map_depth = img.get_height()
	shape.map_data = data
	
	var scale_ratio = chunk_size/float(img.get_width())
