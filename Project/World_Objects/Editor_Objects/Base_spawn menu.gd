extends Panel

## Externally alter the actor id (for loading map data
func set_player_id(id:int):
	$VBoxContainer/tree_type/OptionButton.selected = id+1
	_spawn_player_changed(id+1)

## Set player index onto the base spawn 
func _spawn_player_changed(index):
	var player_index = index-1
	get_parent().preview_node.actor_id = player_index
	match player_index:
		-1:
			get_parent().update_editor_mesh_color(Color(.9,.9,.9,.818))
		0:
			get_parent().update_editor_mesh_color(Color(.196,.204,1,.918))
		1:
			get_parent().update_editor_mesh_color(Color(.734,0,.055,.918))
		2:
			get_parent().update_editor_mesh_color(Color(0.971, 0.693, 0, 0.918))
		3:
			get_parent().update_editor_mesh_color(Color(0, 0.89, 0.532, 0.918))
		4:
			get_parent().update_editor_mesh_color(Color(.479,.263,.667,.918))
		5:
			get_parent().update_editor_mesh_color(Color(0.611, 0, 0.456, 0.918))
