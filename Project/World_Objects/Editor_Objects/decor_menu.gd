extends Panel

func _update_scale(value : float):
	get_parent().preview_node.scale = Vector3(value,value,value)

func _update_v_offset(value : float):
	get_parent().preview_node.position.y = value
	if !get_parent().preview_node.has_meta("vertical_displacement"):
		get_parent().preview_node.set_meta("vertical_displacement",value)

func _update_rot(value : float):
	get_parent().preview_node.rotation_degrees.y = value


##Load values from loaded mesh
func load_values(v_disp:int):
	$VBoxContainer/scale_container/HSlider.value = get_parent().preview_node.scale.x
	$VBoxContainer/Vertical_offset/HSlider.value = v_disp
	get_parent().preview_node.position.y = v_disp
	$VBoxContainer/Rotation/HSlider.value = get_parent().preview_node.rotation_degrees.y
