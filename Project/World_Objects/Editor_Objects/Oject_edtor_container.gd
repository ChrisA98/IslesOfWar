extends Node3D

class_name ObjectEditor

signal delete
signal preparing_to_select


var heightmap ## Heightmap gathered from parents scene
var selected : bool = true:
	set(value):
		if value:
			preparing_to_select.emit()
			for obj in get_tree().get_nodes_in_group("editor_object"):
				if obj != self:
					obj.selected = false
			hide_menu(false)
		else:
			hide_menu()
		selected = value

var active : bool = true ## Can be selected and moved

var preview_node: Node3D ## Node being placed

var following_mouse : bool = true: ## Whether object should follow mouse
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
	
var mouse_pos ## Mouse Position Grabbed from the parent scene

var update_node_function: Callable = Callable(no_update_function) ## Function that should be called when updating node settings

var loaded_in : bool = false ## was loaded in rather than placed

## Level editor using this item
@onready var level_builder_controller = get_parent().get_parent()
@onready var edior_mesh_group = $controller_Handle

@export var object_path: String ## File path for node being placed by this editor object
@export var menu : Node ## Menu node
@export var node_to_save : String ## identifying String to inform save code what to this object is

#region Built-In Functions
func _ready():
	## Get initial heightmap conditions
	heightmap = Global_Vars.heightmap	
	
	## Deselect other editor objects
	for obj in get_tree().get_nodes_in_group("editor_object"):
		if obj != self:
			obj.selected = false
			
	##Create unique mateirals for editor model	
	for mesh in edior_mesh_group.get_child(1).get_children():
		if mesh.mesh.has_method("surface_get_material"):
			mesh.mesh.surface_set_material(0,mesh.mesh.surface_get_material(0).duplicate())
	
	call_deferred("delayed_initialize")
	
	## Dont Spawn object or initialize to preview nod if preview node exists
	if object_path == "":
		return
		
	preview_node = load(object_path).instantiate()
	
	

func _process(_d):
	if following_mouse:
		if Input.is_action_just_released("lmb"):
			following_mouse = false
			$controller_Handle.input_ray_pickable = true
		mouse_pos = level_builder_controller.mouse_position
		set_pos(mouse_pos)


func delayed_initialize():
	await get_tree().physics_frame
	if loaded_in:
		update_node_function.call()
		return
	set_pos(level_builder_controller.mouse_position)


func set_loaded_object():	
	following_mouse = false
	selected = false
	loaded_in = true
	
#endregion


#region Menu Functions


func hide_menu(state := true):
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


## Set location
func set_pos(pos: Vector3):
	heightmap = Global_Vars.heightmap
	pos.y = get_loc_height(pos)
	position = pos
	update_node_function.call()


## get height on map height
func get_loc_height(pos:Vector3, new_hm :bool = false):
	if new_hm:
		heightmap = Global_Vars.heightmap
	@warning_ignore("integer_division")
	var x = pos.x+Global_Vars.heightmap_size/2
	@warning_ignore("integer_division")
	var y = pos.z+Global_Vars.heightmap_size/2
	if x > Global_Vars.heightmap_size or y > Global_Vars.heightmap_size:
		return -10000	
	var t = heightmap.get_pixel(x,y).r * 100
	return clamp(t,0,1000)


##Delete node if active
func delete_node():
	if selected:
		queue_free()
		get_parent().get_parent().world_objects.erase(self)


#endregion


#region Editor mesh functions


func update_editor_mesh_color(new_color : Color):
	edior_mesh_group.get_child(1).mesh.material.albedo_color = new_color
	for mesh in edior_mesh_group.get_child(1).get_children():
		if mesh.mesh.has_method("surface_get_material"):
			mesh.mesh.surface_get_material(0).albedo_color = new_color
		else:
			mesh.mesh.material.albedo_color = new_color
			


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
	set_pos(position)

#region Node_Update Functions

func no_update_function():
	pass

#endregion
