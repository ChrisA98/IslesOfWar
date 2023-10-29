extends Node3D

enum Node_type {NONE,FOREST,STONE,CRYSTAL}

var heightmap: Texture2D
var current_node : Node_type = Node_type.NONE:
	set(value):
		##Set node path
		current_node = value
		match current_node:
			Node_type.NONE:
				world_object_path = ""
			Node_type.FOREST:
				world_object_path = "res://World_Objects/Forest.tscn"
			Node_type.STONE:
				world_object_path = "res://World_Objects/Stone_deposit.tscn"
			Node_type.CRYSTAL:
				world_object_path = "res://World_Objects/Crystal_deposit.tscn"
		spawn_node()
var selected : bool:
	set(value):
		selected = value
		hide_menu(current_node,false)

var world_object_path: String
var preview_node

@onready var menus = [null,get_node("forest_menu"),get_node("stone_menu")]



""" Menu functions"""



## Change menu
func set_active_node(id: int):
	if !is_node_ready():
		return
	current_node = id
	spawn_node()
	hide_menu(menus[current_node])
	hide_menu(menus[current_node],false)


func hide_menu(menu,state := true):
	if menu != null:
		menu.visible = !state



""" Spawn node functions"""



## Spawn node and prepare settings
func spawn_node():
	if preview_node != null:
		preview_node.queue_free()
		preview_node = null
	if world_object_path == "":
		preview_node = Node3D.new()
		return
	preview_node = load(world_object_path).instantiate()
	add_child(preview_node)

