extends unit_building


func _ready():
	super()
	units = [preload("res://Units/Infantry.tscn")]
	type = "Barracks"
	pop_mod = 10

