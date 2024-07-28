extends Node3D

class_name WorldObjectEditor

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
var selected : bool = true:
	set(value):
		if value:
			preparing_to_select.emit()
			for obj in get_tree().get_nodes_in_group("editor_object"):
				if obj != self:
					obj.selected = false
		else:
			for i in range(1,menus.size()):
				hide_menu(menus[i])
		hide_menu(menus[current_node],!value)
		selected = value

var world_object_path: String

var preview_node
var update_node_function: Callable

var following_mouse : bool = true:
	set(value):
		if value:
			for obj in get_tree().get_nodes_in_group("editor_object"):
				if obj != self:
					obj.active = false
			$controller_Handle/editor_mesh.transparency = .2
		else:
			for obj in get_tree().get_nodes_in_group("editor_object"):
				if obj != self:
					obj.active = true
			$controller_Handle/editor_mesh.transparency = .75
		following_mouse = value
		
var mouse_pos

## Can be selected and moved
var active : bool = true

## item was loaded in, not placed
var loaded_in : bool = false


@onready var level_builder_controller = get_parent().get_parent()
@onready var menus = [null,get_node("forest_menu"),get_node("stone_menu"),get_node("crystal_menu")]


func _ready():
	## Get Initial heightmap image
	heightmap = Global_Vars.heightmap
	
	## Deselect other editor objects
	for obj in get_tree().get_nodes_in_group("editor_object"):
		if obj != self:
			obj.selected = false
			
	##Connect node type menus
	for m in menus:
		if m == null:
			continue
		m.get_node("VBoxContainer/node_type/MenuButton").get_popup().id_pressed.connect(set_active_node)
	
	call_deferred("delayed_initialize")


func _process(_d):
	if following_mouse:
		if Input.is_action_just_released("lmb"):
			following_mouse = false
			$controller_Handle.input_ray_pickable = true
		mouse_pos = level_builder_controller.mouse_position
		set_pos(mouse_pos)


func delayed_initialize():
	await get_tree().physics_frame
	if loaded_in == true:
		update_node_function.call()
		return
	set_pos(level_builder_controller.mouse_position)
	

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
	

## Assign node externally (primarily for loading maps purposes)
func load_node(node: world_object):	
	if node is forest:
		set_active_node(WorldObjectEditor.Node_type.FOREST)
		$forest_menu/VBoxContainer/seed_edit/seed_input/TextEdit.text = str(node.random_seed)
		$forest_menu/VBoxContainer/seed_edit/seed_input/TextEdit.text_changed.emit()
		$forest_menu/VBoxContainer/tree_count_edit/density_input/HSlider.value = node.tree_cnt
		$forest_menu/VBoxContainer/tree_count_edit/density_input/HSlider.drag_ended.emit(true)
		$forest_menu/VBoxContainer/forest_size_edit/density_input/HSlider.value = node.radius
		$forest_menu/VBoxContainer/forest_size_edit/density_input/HSlider.drag_ended.emit(true)
		$forest_menu/VBoxContainer/tree_slope/slope_slider/HSlider.value = node.max_slope
		$forest_menu/VBoxContainer/tree_slope/slope_slider/HSlider.value_changed.emit(node.max_slope)
		## Go through tree options and assign id value
		for i in range($forest_menu/VBoxContainer/tree_type/OptionButton.item_count):
			if ($forest_menu/VBoxContainer/tree_type/OptionButton.get_item_text(i) == node.tree_type):
				$forest_menu/VBoxContainer/tree_type/OptionButton.selected = i
				$forest_menu/VBoxContainer/tree_type/OptionButton.item_selected.emit(i)
	else:
		set_active_node(WorldObjectEditor.Node_type.CRYSTAL)
		$crystal_menu/VBoxContainer/crystal_count_edit/density_input/HSlider.value = node.amount
		$crystal_menu/VBoxContainer/crystal_count_edit/density_input/HSlider.drag_ended.emit(true)
		$crystal_menu/VBoxContainer/radius_slider/slider/HSlider.value = node.radius
		$crystal_menu/VBoxContainer/radius_slider/slider/HSlider.value_changed.emit(node.radius)
	following_mouse = false
	selected = false
	loaded_in = true
	update_node_function.call()


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
	if current_node == Node_type.CRYSTAL:
		preview_node.top_level = true



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


## Set location
func set_pos(pos: Vector3):
	heightmap = Global_Vars.heightmap
	pos.y = get_loc_height(pos)
	position = pos
	update_node_function.call()


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



##Delete node if active
func delete_node():
	if selected:
		queue_free()
		get_parent().get_parent().world_objects.erase(self)


## Update node caller
func update_node():
	heightmap = Global_Vars.heightmap
	update_node_function.call()


## Update forest node for global changes or position changes
func _update_forest():
	preview_node.update_heightmap()


## Update forest node for global changes or position changes
func _update_stone():
	preview_node.update_heightmap()


## Update crystal node for global changes or position changes
func _update_crystal():
	preview_node.position.x = position.x
	preview_node.position.z = position.z
	preview_node.update_heightmap()
