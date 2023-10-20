extends Node3D

var strength := 1.0:
	set(value):
		strength = value
		draw_tex.gradient.set_color(0,Color(elevation,elevation,elevation,value))
		draw_tex.gradient.set_color(1,Color(elevation,elevation,elevation,0))


var elevation := .12:
	set(value):
		elevation = value
		draw_tex.gradient.set_color(0,Color(value,value,value,strength))
		draw_tex.gradient.set_color(1,Color(value,value,value,0))


var radius = 50:
	set(value):
		radius = value
		draw_tex.width = value*10
		draw_tex.height = value*10
		display_brush.width = value*10
		display_brush.height = value*10
		$editor_cursor_display.size.x = value*10
		$editor_cursor_display.size.z = value*10


var falloff = 50:
	set(value):
		falloff = 99 - clamp(value,0,99)
		draw_tex.gradient.set_offset(0,falloff/100)
		display_brush.gradient.set_offset(0,falloff/100)
		

@onready var draw_tex = $editor_cursor_drawer.texture_albedo
@onready var display_brush = $editor_cursor_display.texture_albedo


func get_draw_tex():
	return $editor_cursor_drawer.texture_albedo

## Returns brush data for undo and redo commands
func _get_brush_data():
	return [strength,elevation,radius]
