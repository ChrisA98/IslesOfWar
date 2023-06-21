extends Building

@onready var water_checker = get_node("StaticBody3D/Water_Check")


## Set position and chack for water
func set_pos(pos, wait = false):
	super(pos, wait)
	if !_check_water():
		make_invalid()
		return "off water"


## Check if on water
func _check_water():
	if water_checker.get_collider() == null:
		return false
	var t = water_checker.get_collider().get_groups()
	if t.size() == 0:
		return false
			
	if(t[0] == "water"):
		return true
	return false
