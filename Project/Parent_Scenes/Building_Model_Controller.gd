extends Node3D

class_name BuildingModel

var transparency: float:
	set(value):
		transparency = value
		mesh.transparency = value
var player_color : Color


@onready var mesh = get_node("MeshInstance3D")

func _ready():
	for surface in mesh.mesh.get_surface_count():
		var mat = mesh.mesh.surface_get_material(surface)
		if mat != null:
			var t = mat.duplicate(true)
			mesh.mesh.surface_set_material(surface,t)
			


func init(p_color: Color):
	player_color = p_color
	_set_shader_colors()
	

func _set_shader_colors():
	for surface in mesh.mesh.get_surface_count():
		var mat = mesh.mesh.surface_get_material(surface)
		if mat != null:
			mat.set_shader_parameter("player_albedo",player_color)


func set_material_override(mat: Material):
	mesh.set_material_override(mat)
	

## Clear Material overrides
func clear_material_override():
	mesh.set_material_override(null)
	

func set_override_shader_parameter(param:String, value):
	mesh.get_material_override().set_shader_parameter(param, value)
	

##	Sets standard material with albedo color
func set_override_albedo(color):
	if mesh.get_material_override().has_method("get_feature"):
		mesh.get_material_override().albedo_color = color
