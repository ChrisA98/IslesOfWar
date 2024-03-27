extends Node3D

signal delete
signal preparing_to_select


var heightmap ## Heightmap gathered from parents scene
var selected : bool: ## Whether node is selected and menu should be open
	set(value):
		if value:
			preparing_to_select.emit()
		selected = value
var active : bool = true ## Can be selected and moved

var object_path: String ## file path for node being placed
var preview_node: Node3D ## Node being placed

var following_mouse : bool = true ## Whether object should follow scene
var mouse_pos ## Mouse Position Grabbed from the parent scene

var update_node_function: Callable ## Function that should be called when updating node settings

## Level editor using this item
@onready var level_builder_controller = get_parent().get_parent()


#region Built-In Functions
func _ready():
	update_heightmap()
	set_pos(level_builder_controller.mouse_position)
	
	active = true
	

func _process(_d):
	if following_mouse:
		if Input.is_action_just_released("lmb"):
			following_mouse = false
			$controller_Handle.input_ray_pickable = true
		mouse_pos = level_builder_controller.mouse_position
		set_pos(mouse_pos)

#endregion


#region Menu Functions


func hide_menu(menu,state := true):
	if menu != null:
		menu.visible = !state


## Return the preview node for saving
func get_world_object():
	return preview_node



#endregion


#region Node Placement Functions

## Spawn node and prepare settings
func spawn_node():
	if preview_node != null:
		preview_node.queue_free()
		preview_node = null
	if object_path == "":
		preview_node = Node3D.new()
		return
	preview_node = load(object_path).instantiate()
	add_child(preview_node)


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
#endregion


## Mouse Input function
func _on_controller_handle_input_event(_camera, event, _pos, _normal, _shape_idx):
	if !active:
		## Player is not in edit mode
		return
	## Mouse clicks on collision shape
	if event is InputEventMouseButton:
		if event.is_action_pressed("lmb"):
			selected = true
		if !event.is_action_pressed("lmb"):
			following_mouse = false
		return
	## Mouse moves over collision shape
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("lmb"):
			following_mouse = true
			$controller_Handle.input_ray_pickable = false


## Update node settings
func update_node():
	update_node_function.call()

