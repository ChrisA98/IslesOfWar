extends SubViewport

@export var minimap_markers_parameter := "friendly_markers"
@export var draws_fog := true
@export var markers_path : String = "../../UI_Node/Minimap/Minimap_Container/SubViewport/player_markers"

var updates := []
var marker_colors : Color

var visual_ground

#draw fog and mirror parents
var drawers = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	if(draws_fog):
		visual_ground = get_node("../Visual_Ground")
		updates.push_back(_update_fog)
		marker_colors = Color.BLUE
	else:		
		marker_colors = Color.RED
	updates.push_back(_update_markers)
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
	#var tex = get_texture()
	#for c in updates:
	#	c.call(tex)

##Update player minimap fog
func _update_fog(tex):
	visual_ground.mesh.surface_get_material(0).set_shader_parameter("fog", tex)

## Update markers
## should be added always
func _update_markers(tex):
	get_node(markers_path).material.set_shader_parameter(minimap_markers_parameter, tex)
	

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
	m.mesh.surface_set_material(0,StandardMaterial3D.new())
	m.mesh.surface_get_material(0).set_albedo(marker_colors)
	
	m.position = parent.position
	add_child(m)
	parent.update_fog.connect(update_draw, CONNECT_DEFERRED)
	parent.died.connect(remove_drawer.bind(parent))
	
	if(parent.has_signal("fog_radius_changed")):
		parent.fog_radius_changed.connect(update_drawer_radius)
		m.mesh.surface_get_material(0).set_albedo(Color.BLACK)
		m.position.y = -30
	drawers[parent] = m


## Move drawers
func update_draw(parent, pos, visible):
	if(!drawers.has(parent)):
		return
	drawers[parent].visible = visible
	drawers[parent].position.x = pos.x
	drawers[parent].position.z = pos.z


## Update drawe mesh
func update_drawer_radius(parent):
	drawers[parent].mesh.set_bottom_radius(parent.fog_reg.fog_break_radius)
	drawers[parent].mesh.set_top_radius(parent.fog_reg.fog_break_radius)


func remove_drawer(drawer):
	drawers[drawer].queue_free()
	drawers.erase(drawer)
	drawer.update_fog.disconnect(update_draw)
