extends Node3D

@onready var strength := 1.0:
	set(value):
		strength = value
		draw_tex.gradient.set_color(0,Color(elevation,elevation,elevation,value))
		draw_tex.gradient.set_color(1,Color(elevation,elevation,elevation,0))
		draw_img = $editor_cursor_drawer.texture_albedo.get_image()
		img_scale = draw_img.get_size().x


@onready var elevation := .12:
	set(value):
		elevation = value
		draw_tex.gradient.set_color(0,Color(value,value,value,strength))
		draw_tex.gradient.set_color(1,Color(value,value,value,0))
		draw_img = $editor_cursor_drawer.texture_albedo.get_image()


@onready var radius = 50:
	set(value):
		radius = value
		draw_tex.width = value*10
		draw_tex.height = value*10
		display_brush.width = value*10
		display_brush.height = value*10
		$editor_cursor_display.size.x = value*10
		$editor_cursor_display.size.z = value*10
		draw_img = $editor_cursor_drawer.texture_albedo.get_image()


var falloff = 50:
	set(value):
		falloff = 99 - clamp(value,0,99)
		draw_tex.gradient.set_offset(0,falloff/100)
		display_brush.gradient.set_offset(0,falloff/100)
		draw_img = $editor_cursor_drawer.texture_albedo.get_image()


var paint_tex : Image
var img_scale : float = 1

@onready var draw_tex = $editor_cursor_drawer.texture_albedo
@onready var display_brush = $editor_cursor_display.texture_albedo
@onready var draw_img = $editor_cursor_drawer.texture_albedo.get_image()


func get_draw_tex():
	return $editor_cursor_drawer.texture_albedo


## Returns brush data for undo and redo commands
func _get_brush_data():
	return [strength,elevation,radius]
