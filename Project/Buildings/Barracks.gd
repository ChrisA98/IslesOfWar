extends Building


var units = [preload("res://Units/Infantry.tscn")]


func _ready():
	super()
	type = "Barracks"
	cost["wood"] = 10
	cost["stone"] = 10
	pop_mod = 10


func set_pos(pos):
	super(pos)
	if near_base(actor_owner.bases) == false:
		make_invalid()


## Spawn unit and validate spawning
func use(_unit):
	var new_unit = units[0].instantiate()
	if world.spawn_unit(actor_owner, new_unit):
		new_unit.position = spawn.global_position
		new_unit.set_mov_target(rally.global_position)
		return true
	return false
