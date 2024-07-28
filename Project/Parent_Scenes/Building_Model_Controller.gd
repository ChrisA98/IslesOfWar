extends Node3D

class_name BuildingModel

signal mats_ready

@export var grnd_align : bool = false

var transparency: float:
	set(value):
		transparency = value
		mesh.transparency = value
var player_color : Color
## Flag to notify when the materials are ready to be edited
var mat_ready := false


@onready var mesh = get_node("MeshInstance3D")

func _ready():
	mesh.mesh = mesh.mesh.duplicate(true)
	call_deferred("_prepare_materials")
	burn(0)

func _prepare_materials():
	for surface in mesh.mesh.get_surface_count():
		var mat = mesh.mesh.surface_get_material(surface)
		if mat != null:
			var t = mat.duplicate(true)
			mesh.mesh.surface_set_material(surface,t)
	mat_ready = true
	mats_ready.emit()


func init(p_color: Color):
	player_color = p_color
	_set_shader_colors()
	

func _set_shader_colors():
	if(!mat_ready):
		await mats_ready
	for surface in mesh.mesh.get_surface_count():
		var mat = mesh.mesh.surface_get_material(surface)
		if mat != null:
			mat.set_shader_parameter("player_albedo",player_color)
	for _mesh in get_children():
		if !(_mesh is MeshInstance3D):
			continue
		for surface in _mesh.mesh.get_surface_count():
			var mat = _mesh.mesh.surface_get_material(surface)
			if mat != null and (mat is ShaderMaterial):
				mat.set_shader_parameter("player_albedo",player_color)


func set_material_override(mat: Material):
	for _mesh in get_children():
		if !(_mesh is MeshInstance3D):
			continue
		_mesh.set_material_override(mat)
	

## Clear Material overrides
func clear_material_override():
	for _mesh in get_children():
		if _mesh.has_meta("hide"):
			_mesh.visible = true
		if !(_mesh is MeshInstance3D):
			continue
		_mesh.set_material_override(null)
	

func set_override_shader_parameter(param:String, value):
	mesh.get_material_override().set_shader_parameter(param, value)
	

##	Sets standard material with albedo color
func set_override_albedo(color):
	if mesh.get_material_override().has_method("get_feature"):
		mesh.get_material_override().albedo_color = color

## Start building building
func build(_build_shader,magic_color):
	set_material_override(_build_shader)
	set_override_shader_parameter("magic_color", magic_color)
	for _mesh in get_children():
		if _mesh.has_meta("hide"):
			_mesh.visible = false

## Turn on damage smoke
func burn(deg : int = 0):
	if deg == 0:
		$Damage/Damage.visible = false
		$Damage/Damage2.visible = false
		$Damage/Damage3.visible = false
	if deg >= 1:
		$Damage/Damage.visible = true
	if deg >= 2:
		$Damage/Damage2.visible = true
	if deg >= 3:
		$Damage/Damage3.visible = true
