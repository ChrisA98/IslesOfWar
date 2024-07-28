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
				gnd_menu.visible = false
			obj_menu:
				obj_menu.visible = true
				terrain_menu.visible = false
				gnd_menu.visible = false
			gnd_menu:
				gnd_menu.visible = true
				terrain_menu.visible = false
				obj_menu.visible = false

var active_terrain_brush
var water_level: float = 7

@onready var terrain_menu = get_node("Brush_Panel")
@onready var obj_menu = get_node("Place_Obj_Panel")
@onready var gnd_menu = get_node("Ground_Brush_Panel")
@onready var brush = get_node("../editor_cursor")
@onready var level = get_node("../level")
@onready var terrain_brushes = get_parent().terrain_textures


#region Built Ins
func _ready():
	
	## Connect brush type changeing button to update thise node
	$Brush_Panel/HBoxContainer/brush_Mode/MenuButton.get_popup().id_pressed.connect(_brush_type_changed)
	## Connect spawnable world objects to spawn world objects
	$Place_Obj_Panel/HBoxContainer/World_Objects/world_objects_list.get_popup().id_pressed.connect(_spawn_world_object)
	$Place_Obj_Panel/HBoxContainer/Item_Box3/MenuButton.get_popup().id_pressed.connect(_spawn_gameplay_object)
	## Set editor viewport aspect ratio
	$editor_overlay_viewport/SubViewport.size.x = ProjectSettings.get_setting("display/window/size/viewport_width")
	$editor_overlay_viewport/SubViewport.size.y = ProjectSettings.get_setting("display/window/size/viewport_height")
	
	## Load decor Items
	load_decor_objects()
	
	call_deferred("_set_brush_defaults")

func _input(event):		
	## Toggle pause menu visibility
	if event.is_action_pressed(("esc")):
		$pause_curtain.visible = !$pause_curtain.visible
		if(!$pause_menu.visible):
			$pause_menu.visible = $pause_curtain.visible
		else:
			$pause_menu.visible = !$pause_menu.visible
		if($save_menu.visible):
			$save_menu.visible = $pause_curtain.visible
		if($overwrite_menu.visible):
			$overwrite_menu.visible = $pause_curtain.visible
		
		
		if ($pause_curtain.visible):
			$"..".process_mode = Node.PROCESS_MODE_DISABLED
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			return
		$"..".process_mode = Node.PROCESS_MODE_INHERIT
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED) 

#endregion

## Set default values for brush
func _set_brush_defaults():
	await  get_tree().physics_frame
	brush.strength = .5
	brush.elevation = .5
	brush.radius = 50
	brush.falloff = 50
	RenderingServer.global_shader_parameter_set("water_depth",water_level)
	Global_Vars.water_elevation = water_level




#region Terrain Paint Brush Controls


## Load textures for the terain brush
func load_textures():
	for t in get_parent().terrain_textures:
		$Ground_Brush_Panel/HBoxContainer/Texture/OptionButton.add_item(t)
	$Ground_Brush_Panel/HBoxContainer/Texture/OptionButton.selected = 0
	call_deferred("_initialize_tex_brush")


## Set default texture for texture brush
func _initialize_tex_brush():
	await get_tree().physics_frame
	var default_tex = $Ground_Brush_Panel/HBoxContainer/Texture/OptionButton.get_item_text(0)
	_change_paint_image(terrain_brushes[default_tex].get_image())


## UI texture option button changed value
func _texture_changed(id):
	var tex_name = $Ground_Brush_Panel/HBoxContainer/Texture/OptionButton.get_item_text(id)
	_change_paint_image(terrain_brushes[tex_name].get_image())


## Set active paint image and snd it to the brush
func _change_paint_image(image):
	if image == null:
		return
	active_terrain_brush = image
	brush.paint_tex = active_terrain_brush

#endregion


#region Terrain Brush Controls



func strength_slider_used(value):
	brush.strength = value/200
	$Brush_Panel/HBoxContainer/Brush_Strength/value.text = "[center]"+str(value)+"[/center]"
	$Ground_Brush_Panel/HBoxContainer/Brush_Strength/value.text = "[center]"+str(value)+"[/center]"
	$Ground_Brush_Panel/HBoxContainer/Brush_Strength/Slider.value = value
	$Brush_Panel/HBoxContainer/Brush_Strength/Slider.value = value
	

func elevation_slider_used(value):
	brush.elevation = value/100
	$Brush_Panel/HBoxContainer/Brush_Elevation/value.text = "[center]"+str(value)+"[/center]"
	
	
func radius_slider_used(value):
	brush.radius = value
	$Brush_Panel/HBoxContainer/Brush_Radius/value.text = "[center]"+str(value)+"[/center]"
	$Ground_Brush_Panel/HBoxContainer/Brush_Radius/value.text = "[center]"+str(value)+"[/center]"
	$Brush_Panel/HBoxContainer/Brush_Radius/Slider.value = value
	$Ground_Brush_Panel/HBoxContainer/Brush_Radius/Slider.value = value
	

func falloff_slider_used(value):
	brush.falloff = value
	$Brush_Panel/HBoxContainer/Brush_Falloff/value.text = "[center]"+str(value)+"[/center]"
	$Ground_Brush_Panel/HBoxContainer/Brush_Falloff/value.text = "[center]"+str(value)+"[/center]"
	$Ground_Brush_Panel/HBoxContainer/Brush_Falloff/Slider.value = value
	$Brush_Panel/HBoxContainer/Brush_Falloff/Slider.value = value


func water_level_slider_used(value):
	RenderingServer.global_shader_parameter_set("water_depth",value)
	Global_Vars.water_elevation = value
	water_level = value
	$Brush_Panel/HBoxContainer/World_Water_Level/value.text = "[center]"+str(value)+"[/center]"

#endregion


#region Spawn Objects 


## Spawn World Objects
func _spawn_world_object(id):
	var new_node = load("res://World_Objects/Editor_Objects/world_object_edtor_container.tscn").instantiate()
	level.add_child(new_node)
	new_node.set_active_node(id)
	
	object_added.emit(new_node)


func _spawn_gameplay_object(id):
	var new_node
	match id:
		0:
			new_node = load("res://World_Objects/Editor_Objects/base_spawn_editor.tscn").instantiate()
	level.add_child(new_node)
	
	object_added.emit(new_node)


## Spawn decor item editor object
func _spawn_decor_object(item_id : int):
	## Get item text from menu
	var item_name  = $Place_Obj_Panel/HBoxContainer/Decorations/MenuButton.get_popup().get_item_text(item_id)
	item_name = item_name.to_lower().replace(" ","_")
	var new_node = load("res://World_Objects/Editor_Objects/decor_editor.tscn").instantiate()
	var dir = DirAccess.open("res://Assets/Models/Decorations/")
	new_node.preview_node = MeshInstance3D.new()
	var options = dir.get_files()
	
	## Find the file specficied
	## May need reworking if a lot of decor gets added
	for item in dir.get_files():
		if item.match("*"+item_name+"*"):
			item_name = item
			
	# Remove .remap extension if present
	if item_name.ends_with(".remap"):
		item_name = item_name.substr(0, item_name.length() - 6)
	
	new_node.preview_node.mesh = load("res://Assets/Models/Decorations/"+item_name)
	new_node.add_child(new_node.preview_node)
	
	level.add_child(new_node)
	object_added.emit(new_node)



## Load Decorations
func load_decor_objects():
	var dir = DirAccess.open("res://Assets/Models/Decorations/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.get_extension() == "import":
				file_name = dir.get_next()
				continue
			# Remove .remap extension if present
			if file_name.ends_with(".remap"):
				file_name = file_name.substr(0, file_name.length() - 6)
			var n = file_name.get_basename()
			
			## Convert text to capitalize each word with spaces between
			n = n.replace("_"," ")
			n = n.substr(0,1).to_upper()+n.substr(1)
			for c in range(n.length()-1):
				if n.substr(c,1) == " " and !n.substr(c+1,1).is_valid_int():
					n = n.left(c+1)+ n.substr(c+1,1).to_upper()+n.right(n.length()-c-2)
			## Add to list
			$Place_Obj_Panel/HBoxContainer/Decorations/MenuButton.get_popup().add_item(n)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
		
	$Place_Obj_Panel/HBoxContainer/Decorations/MenuButton.get_popup().id_pressed.connect(_spawn_decor_object)


#endregion


#region General Menu Controls



func _brush_type_changed(id):
	brush_changed.emit(id)
	var brush_mode = $Brush_Panel/HBoxContainer/brush_Mode/MenuButton.get_popup().get_item_text(id)
	$Brush_Panel/HBoxContainer/brush_Mode/MenuButton.text = brush_mode


## Mouse is on menu
func _mouse_entered_toolbar():
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	mouse_used = true
	$"../editor_cursor/editor_cursor_display".visible = false


## Mouse is off menu
func _mouse_exited_toolbar():
	mouse_used = false
	if(active_menu == terrain_menu):
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
	$"../editor_cursor/editor_cursor_display".visible = true


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
	

## change edit mode to edit atmosphere
func edit_ground_pressed():
	active_menu = gnd_menu
	edit_mode_changed.emit("ground")

#endregion
