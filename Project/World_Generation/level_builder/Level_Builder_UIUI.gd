extends Control

var mouse_used := false

@onready var b_strength_slider = get_node("Brush_Panel/Brush_Strength/Slider")
@onready var brush = get_node("../editor_cursor")

func strength_slider_used(value):
	brush.strength = value/100
	$Brush_Panel/Brush_Strength/value.text = str(value)
	

func elevation_slider_used(value):
	brush.elevation = value/100
	$Brush_Panel/Brush_Elevation/value.text = str(value)
	
	
func radius_slider_used(value):
	brush.radius = value
	$Brush_Panel/Brush_Radius/value.text = str(value)	
	

func falloff_slider_used(value):
	brush.falloff = value
	$Brush_Panel/Brush_Falloff/value.text = str(value)	


func water_level_slider_used(value):
	RenderingServer.global_shader_parameter_set("water_depth",value)
	$Brush_Panel/World_Water_Level/value.text = str(value)	
	

func _mouse_entered_toolbar():
	mouse_used = true

func _mouse_exited_toolbar():
	mouse_used = false
