extends Node3D

signal delete
signal preparing_to_select

enum Node_type {NONE,FOREST,STONE,CRYSTAL}

var heightmap
var current_node : Node_type = Node_type.NONE:
	set(value):
		##Set node path
		current_node = value
		match current_node:
			Node_type.NONE:
				world_object_path = ""
			Node_type.FOREST:
				world_object_path = "res://World_Objects/Forest.tscn"
				update_node_function = Callable(_update_forest)
			Node_type.STONE:
				world_object_path = "res://World_Objects/Stone_deposit.tscn"
				update_node_function = Callable(_update_stone)
			Node_type.CRYSTAL:
				world_object_path = "res://World_Objects/Crystal_deposit.tscn"
				update_node_function = Callable(_update_crystal)
		spawn_node()
var selected : bool:
	set(value):
		if value:
			preparing_to_select.emit()
		else:
			for i in range(1,menus.size()):
				hide_menu(menus[i])
		hide_menu(menus[current_node],!value)
		selected = value

var world_object_path: String

var preview_node
var update_node_function: Callable

var following_mouse : bool = true
var mouse_pos

## Can be selected and moved
var active : bool = true


@onready var level_builder_controller = get_parent().get_parent()
@onready var menus = [null,get_node("forest_menu"),get_node("stone_menu"),get_node("crystal_menu")]


func _ready():
	update_heightmap()
	set_pos(level_builder_controller.mouse_position)
	
	active = true
	
	##Connect node type menus
	for m in menus:
		if m == null:
			continue
		m.get_node("VBoxContainer/node_type/MenuButton").get_popup().id_pressed.connect(set_active_node)


func _process(_d):
	if following_mouse:
		if Input.is_action_just_released("lmb"):
			following_mouse = false
			$controller_Handle.input_ray_pickable = true
		mouse_pos = level_builder_controller.mouse_position
		set_pos(mouse_pos)


""" Menu functions"""



## Change menu
func set_active_node(id: int):
	if !is_node_ready():
		return
	hide_menu(menus[current_node])
	@warning_ignore("int_as_enum_without_cast")
	current_node = id
	spawn_node()
	hide_menu(menus[current_node],false)


func hide_menu(menu,state := true):
	if menu != null:
		menu.visible = !state


## Return the preview node for saving
func get_world_object():
	return preview_node



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



func _on_controller_handle_input_event(_camera, event, _pos, _normal, _shape_idx):
	if !active:
		## Player is not in edit mode
		return
	if event is InputEventMouseButton:
		if event.is_action_pressed("lmb"):
			selected = true
		if !event.is_action_pressed("lmb"):
			following_mouse = false
		return
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("lmb"):
			following_mouse = true
			$controller_Handle.input_ray_pickable = false


""" Node Placement Functions"""



func update_heightmap():
	heightmap = Global_Vars.heightmap
	set_pos(position)


## Set location
func set_pos(pos: Vector3):
	pos.y = get_loc_height(pos)
	position = pos


## get height on map height
func get_loc_height(pos:Vector3):
	@warning_ignore("integer_division")
	var x = pos.x+Global_Vars.heightmap_size/2
	@warning_ignore("integer_division")
	var y = pos.z+Global_Vars.heightmap_size/2
	if x > Global_Vars.heightmap_size or y > Global_Vars.heightmap_size:
		return -10000	
	var t = heightmap.get_pixel(x,y).r * 100
	return clamp(t,0,1000)



""" Node Update Functions"""



## Update node caller
func update_node():
	update_node_function.call()


## Update forest node for global changes or position changes
func _update_forest():
	update_heightmap()
	preview_node.update_heightmap()


## Update forest node for global changes or position changes
func _update_stone():
	pass


## Update forest node for global changes or position changes
func _update_crystal():
	pass
