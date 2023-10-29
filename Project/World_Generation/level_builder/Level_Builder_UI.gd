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
			obj_menu:
				obj_menu.visible = true
				terrain_menu.visible = false
				

@onready var terrain_menu = get_node("Brush_Panel")
@onready var brush = get_node("../editor_cursor")
@onready var obj_menu = get_node("Place_Obj_Panel")
@onready var level_objects = get_node("../level")


""" built-in """
func _ready():
	$Brush_Panel/HBoxContainer/brush_Mode/MenuButton.get_popup().id_pressed.connect(_brush_type_changed)
	$Place_Obj_Panel/HBoxContainer/World_Objects/world_objects_list.get_popup().id_pressed.connect(_spawn_world_object)
	call_deferred("_set_brush_defaults")


func _set_brush_defaults():
	await get_tree().physics_frame
	$Brush_Panel/HBoxContainer/Brush_Strength/Slider.value = 12
	strength_slider_used(12)
	$Brush_Panel/HBoxContainer/Brush_Elevation/Slider.value =  12
	elevation_slider_used(12)
	$Brush_Panel/HBoxContainer/Brush_Radius/Slider.value = 50
	radius_slider_used(50)
	$Brush_Panel/HBoxContainer/Brush_Falloff/Slider.value = 50
	falloff_slider_used(50)



""" Brush Controls"""



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
	$Brush_Panel/HBoxContainer/World_Water_Level/value.text = "[center]"+str(value)+"[/center]"



""" Spawn Objects"""



## Spawn World Objects
func _spawn_world_object(id):
	var new_node = load("res://World_Objects/Editor_Objects/world_object_edtor_container.tscn").instantiate()
	level_objects.add_child(new_node)
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
