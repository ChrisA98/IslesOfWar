extends Panel


""" Seed Inputs"""

## Ensure the text in the seed line is always an integer
func seed_text_changed():
	var text = $VBoxContainer/seed_edit/seed_input/TextEdit.get_text()
	$VBoxContainer/seed_edit/seed_input/TextEdit.set_text(str(text.to_int()))


## Seed enter button pressed
func seed_changed():
	var t = $VBoxContainer/seed_edit/seed_input/TextEdit.get_text()
	get_parent().preview_node.random_seed = t.to_int()
	

## Density changed
func density_changed(value_changed):
	if value_changed:
		var density = $VBoxContainer/tree_count_edit/density_input/HSlider.value
		get_parent().preview_node.tree_cnt = density
	

## Slope Changed
func slope_changed(value):
	var max_slope = $VBoxContainer/tree_slope/slope_slider/HSlider.value
	get_parent().preview_node.max_slope = max_slope
