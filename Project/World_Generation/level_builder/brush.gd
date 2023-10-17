extends Node3D

var strength := 1.0

@onready var draw_tex = $editor_cursor_drawer.texture_albedo
@onready var erase_tex = $editor_cursor_eraser.texture_albedo

func _ready():
	draw_tex.gradient.set_color(0,Color(strength,strength,strength,.1))
	
func _process(_dx):
	draw_tex.gradient.set_color(0,Color(strength,strength,strength,.1))
