extends Building

@onready var world = get_parent().get_parent()
var units = [preload("res://Units/Infantry.tscn")]

func _ready():
	super()
	type = "Barracks"

func set_pos(pos):
	position = pos + Vector3(0,(scale.y/2)*.95,0)
	if snapping > 1:
		position.x = ceil(position.x/snapping)*snapping
		position.z = ceil(position.z/snapping)*snapping
	if check_collision(collision_buffer):
		pass
	if near_base(world.forts):
		make_valid()
		return
	make_invalid()


func near_base(buildings) -> bool:
	if buildings == null:
		return false
	for b in buildings:
		if b.position.distance_to(position) < b.radius:
			return true
	return false


func use(unit):
	var new_unit = units[0].instantiate()
	world.spawn_unit(new_unit)
	new_unit.position = spawn.global_position
	new_unit.set_mov_target(rally.global_position)
