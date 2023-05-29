extends SubViewport

@onready var visual_ground = $"../../World/Visual_Ground"
@onready var test_guide = $"../Player_camera"

#draw fog and mirror parents
var drawers = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):	
	var tex = get_texture()
	visual_ground.mesh.surface_get_material(0).set_shader_parameter("fog", tex)


## Create the radius drawers
func create_drawer(parent):
	var m = MeshInstance3D.new()
	## build mesh
	m.set_mesh(CylinderMesh.new())
	m.mesh.set_bottom_radius(parent.fog_reg.fog_break_radius)
	m.mesh.set_cap_bottom(false)
	m.mesh.set_radial_segments(32)
	m.mesh.set_rings(1)
	m.mesh.set_top_radius(parent.fog_reg.fog_break_radius)
	
	m.position = parent.position
	add_child(m)
	parent.update_fog.connect(update_draw)
	if(parent.has_signal("fog_radius_changed")):
		parent.fog_radius_changed.connect(update_drawer_radius)
	drawers[parent] = m


## Move drawers
func update_draw(parent, pos):
	drawers[parent].position = pos


## Update drawe mesh
func update_drawer_radius(parent):
	drawers[parent].mesh.set_bottom_radius(parent.fog_reg.fog_break_radius)
	drawers[parent].mesh.set_top_radius(parent.fog_reg.fog_break_radius)
