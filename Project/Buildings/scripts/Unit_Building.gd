extends Building

class_name unit_building

var units


func _ready():
	super()


## Spawn unit and validate spawning
func use(_unit):
	var new_unit = units[0].instantiate()
	if world.spawn_unit(actor_owner, new_unit):
		new_unit.position = spawn.global_position
		new_unit.set_mov_target(rally.global_position)
		return true
	return false
