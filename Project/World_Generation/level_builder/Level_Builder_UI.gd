extends Control

signal edit_mode_changed
signal brush_changed
signal object_added

var mouse_used := false
var active_menu = terrain_menu:
	set(value):
		active_menu = value
		match value:
			terrain_menu:
				terrain_menu.visible = true
				obj_menu.visible = false
				gnd_menu.visible = false
			obj_menu:
				obj_menu.visible = true
				terrain_menu.visible = false
				gnd_menu.visible = false
			gnd_menu:
				gnd_menu.visible = true
				terrain_menu.visible = false
				obj_menu.visible = false

var active_terrain_brush
var water_level: float = 7

@onready var terrain_menu = get_node("Brush_Panel")
@onready var obj_menu = get_node("Place_Obj_Panel")
@onready var gnd_menu = get_node("Ground_Brush_Panel")
@onready var brush = get_node("../editor_cursor")
@onready var level = get_node("../level")
@onready var terrain_brushes = get_parent().terrain_textures


""" built-in """
func _ready():
	
	## Connect brush type changeing button to update thise node
	$Brush_Panel/HBoxContainer/brush_Mode/MenuButton.get_popup().id_pressed.connect(_brush_type_changed)
	## Connect spawnable world objects to spawn world objects
	$Place_Obj_Panel/HBoxContainer/World_Objects/world_objects_list.get_popup().id_pressed.connect(_spawn_world_object)
	## Set editor viewport aspect ratio
	$editor_overlay_viewport/SubViewport.size.x = ProjectSettings.get_setting("display/window/size/viewport_width")
	$editor_overlay_viewport/SubViewport.size.y = ProjectSettings.get_setting("display/window/size/viewport_height")
	
	call_deferred("_set_brush_defaults")


## Set default values for brush
func _set_brush_defaults():
	brush.strength = .5
	brush.elevation = .5
	brush.radius = 50
	brush.falloff = 50


## Load textures for the terain brush
func load_textures():
	for t in get_parent().terrain_textures:
		$Ground_Brush_Panel/HBoxContainer/Texture/OptionButton.add_item(t)
	$Ground_Brush_Panel/HBoxContainer/Texture/OptionButton.selected = 0
	call_deferred("_initialize_tex_brush")

## Set default texture for texture brush
func _initialize_tex_brush():
	await get_tree().physics_frame
	var default_tex = $Ground_Brush_Panel/HBoxContainer/Texture/OptionButton.get_item_text(0)
	_change_paint_image(terrain_brushes[default_tex].get_image())



""" Terrain Paint Brush Controls"""


## UI texture option button changed value
func _texture_changed(id):
	var tex_name = $Ground_Brush_Panel/HBoxContainer/Texture/OptionButton.get_item_text(id)
	_change_paint_image(terrain_brushes[tex_name].get_image())


## Set active paint image and snd it to the brush
func _change_paint_image(image):
	if image == null:
		return
	active_terrain_brush = image
	brush.paint_tex = active_terrain_brush



""" Terrain Brush Controls"""



func strength_slider_used(value):
	brush.strength = value/100
	$Brush_Panel/HBoxContainer/Brush_Strength/value.text = "[center]"+str(value)+"[/center]"
	

func elevation_slider_used(value):
	brush.elevation = value/100
	$Brush_Panel/HBoxContainer/Brush_Elevation/value.text = "[center]"+str(value)+"[/center]"
	
	
func radius_slider_used(value):
	brush.radius = value
	$Brush_Panel/HBoxContainer/Brush_Radius/value.text = "[center]"+str(value)+"[/center]"
	

func falloff_slider_used(value):
	brush.falloff = value
	$Brush_Panel/HBoxContainer/Brush_Falloff/value.text = "[center]"+str(value)+"[/center]"


func water_level_slider_used(value):
	RenderingServer.global_shader_parameter_set("water_depth",value)
	Global_Vars.water_elevation = value
	water_level = value
	$Brush_Panel/HBoxContainer/World_Water_Level/value.text = "[center]"+str(value)+"[/center]"



""" Spawn Objects"""



## Spawn World Objects
func _spawn_world_object(id):
	var new_node = load("res://World_Objects/Editor_Objects/world_object_edtor_container.tscn").instantiate()
	level.add_child(new_node)
	new_node.set_active_node(id)
	
	object_added.emit(new_node)
	

""" General Menu Controls"""



func _brush_type_changed(id):
	brush_changed.emit(id)
	var brush_mode = $Brush_Panel/HBoxContainer/brush_Mode/MenuButton.get_popup().get_item_text(id)
	$Brush_Panel/HBoxContainer/brush_Mode/MenuButton.text = brush_mode


## Mouse is on menu
func _mouse_entered_toolbar():
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	mouse_used = true


## Mouse is off menu
func _mouse_exited_toolbar():
	mouse_used = false
	if(active_menu == terrain_menu):
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)


## change edit mode to edit terrain
func edit_terrain_pressed():
	active_menu = terrain_menu
	edit_mode_changed.emit("terrain")


## change edit mode to place objects
func place_objects_pressed():
	active_menu = obj_menu
	edit_mode_changed.emit("place")


## change edit mode to edit atmosphere
func edit_atmosphere_pressed():
	edit_mode_changed.emit("atmos")
	

## change edit mode to edit atmosphere
func edit_ground_pressed():
	active_menu = gnd_menu
	edit_mode_changed.emit("ground")
