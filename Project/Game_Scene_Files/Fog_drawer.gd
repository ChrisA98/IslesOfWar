extends SubViewport

@export var minimap_markers_parameter := "friendly_markers"
@export var draws_fog := true
@export var markers_path : String = "../../UI_Node/Minimap/Minimap_Container/SubViewport/player_markers"

var updates := []
var unit_list := []
var marker_colors : Color

var visual_ground

var timer

#draw fog and mirror parents
var drawers = {}

@onready var circle = preload("res://Game_Scene_Files/UI_Elements/fow_circle.tres")
@onready var circle_shading = preload("res://Materials/minimap_icon_recolorer.gdshader")

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
	var tex = get_texture()
	for c in updates:
		c.call(tex)


func _physics_process(_delta):
	for i in range(clamp(unit_list.size(),0,25)):
		_update_drawers_pos()


func _update_drawers_pos():
	var t = unit_list.pop_front()
	if _update_draw(t):
		unit_list.push_back(t)


##Update player minimap fog
func _update_fog(tex):
	RenderingServer.global_shader_parameter_set("fog_tex",tex)


## Update markers
## should be added always
func _update_markers(tex):
	get_node(markers_path).material.set_shader_parameter(minimap_markers_parameter, tex)
	

## Create the radius drawers
func create_drawer(parent):
	var s = Sprite2D.new()
	s.texture = circle
	s.set_material(ShaderMaterial.new())
	s.material.set_shader(circle_shading)
	s.material.set_shader_parameter("icon_color",marker_colors)
	var size_mod = parent.fog_reg.fog_break_radius/40
	s.scale = Vector2(size_mod,size_mod)
	
	s.position = Vector2(parent.position.x,parent.position.z)
	drawers[parent] = s
	add_child(s)
	
	parent.died.connect(remove_drawer.bind(parent))
	parent.update_fog.connect(edit_active_drawers)
	
	if(parent.has_signal("fog_radius_changed")):
		parent.fog_radius_changed.connect(update_drawer_radius)
		s.material.set_shader_parameter("icon_color",Color.BLACK)
		return
	
	unit_list.push_front(parent)


func edit_active_drawers(unit,add:bool):
	if !add:
		unit_list.erase(unit)
		return
	if drawers.has(unit) and !unit_list.has(unit):
		unit_list.push_front(unit)


## Move drawers
func _update_draw(parent):
	if (!drawers.has(parent) or !is_instance_valid(parent)):
		return false
	drawers[parent].visible = parent.visible
	drawers[parent].position.x = parent.position.x
	drawers[parent].position.y = parent.position.z
	return true


## Update drawe mesh
func update_drawer_radius(parent):
	var size_mod = parent.fog_reg.fog_break_radius/40
	drawers[parent].scale = Vector2(size_mod,size_mod)


func remove_drawer(drawer):
	if drawers.has(drawer):
		drawers[drawer].queue_free()
		drawers.erase(drawer)
