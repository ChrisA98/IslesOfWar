extends Panel

var use_random_spawns : bool

@onready var overwrite_menu :Node = get_node("../overwrite_menu")
@onready var level_builder = get_parent().get_parent()


func _save(overwrite: bool = false):
	var level_name:String = $VBoxContainer/level_name.text
	if level_name == "":
		return
	level_name = level_name.replace(" ","_")
	var year = int($VBoxContainer/start_date/year.text)
	var day = Global_Vars.get_year_day($VBoxContainer/start_date/OptionButton.get_item_text($VBoxContainer/start_date/OptionButton.selected),int($VBoxContainer/start_date/year3.text))

	var dir = DirAccess.open("res://")
	
	## Check for level existing
	if (dir.dir_exists("Assets/Levels/"+level_name+"/")):
		if !overwrite:
			## Notify level exists already and open overwrite menu
			overwrite_menu.visible = true
			return
			
	
	$"../saving_icon".visible = true
	
	## Write save values to level builder
	if level_name != "":
		level_builder.level_name = level_name
	level_builder.level_year = year
	level_builder.level_year_day = day
	level_builder.level_uses_rnd_spawns = use_random_spawns
	
	## Tell level Builder to save map
	level_builder.save_map()


## Random Spawns toggled
func _toggle_random_spawns(state: bool):
	use_random_spawns = state


func close_save_menu():
	visible = false
	$"../pause_menu".visible = true


func _hide_overwrite_menu():
	$"../overwrite_menu".visible = false


func _day_updated():
	var text = $VBoxContainer/start_date/year3
	if text.text.is_valid_int():
		if int(text.text) > 28 or int(text.text) < 0:
			text.text = str(clampi(int(text.text),0,28))
			text.set_caret_column(text.text.length())
		return
	text.text = ""
	text.set_caret_column(text.text.length())

func year_update():
	var text = $VBoxContainer/start_date/year
	if text.text.is_valid_int():
		if int(text.text) > 999 or int(text.text) < 0:
			text.text = str(clampi(int(text.text),0,999))
			text.set_caret_column(text.text.length())
		return
	text.text = ""
	text.set_caret_column(text.text.length())
