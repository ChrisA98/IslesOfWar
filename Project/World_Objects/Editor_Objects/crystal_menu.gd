extends Panel

signal node_type_changed


## Crystal Amount Edited
func _on_h_slider_drag_ended(value_changed):
	if value_changed and is_node_ready():
		var value = $VBoxContainer/crystal_count_edit/density_input/HSlider.value
		get_parent().preview_node.amount = value


## Deposit Radius Edited
func radius_changed_drag_ended(new_value):
	if is_node_ready():
		var value = $VBoxContainer/radius_slider/slider/HSlider.value
		get_parent().preview_node.radius = value
