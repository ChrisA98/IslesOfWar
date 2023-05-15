extends unit_building

func _ready():
	super()
	menu = get_node("Barracks_Menu")
	units = [preload("res://Units/Infantry.tscn")]
	type = "Barracks"
	pop_mod = 10
