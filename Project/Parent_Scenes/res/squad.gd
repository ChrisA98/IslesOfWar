extends Object

class_name Squad

enum formations{COLUMNS}

var active_formation: formations:
	set(value):
		match value:
			formations.COLUMNS:
				formation_call = Callable(_columns_formation)
var formation_size : int
var units : Array[Unit_Base]
var formation_call : Callable = Callable(_columns_formation)

## Get formation_position
func get_formation_pos(unit: Unit_Base):
	return formation_call.call(unit)


func set_active_formation(type: formations):
	active_formation = type


## Take array of selected units and make a squad
func build_squad(s_units):
	units = s_units.duplicate()
	s_units = self
	units.sort_custom(_sort_by_id)


## Check if squad has unit
func has(unit) -> bool:
	return units.has(unit)


## Erase unit from squad
func erase(unit):
	units.erase(unit)


## Remove any units in squad that exist in target array
func erase_array(trgt_units: Array):
	for i in trgt_units:
		erase(i)


## Add unit to squad
func push_back(unit):
	units.push_back(unit)
	units.sort_custom(_sort_by_id)


## Sort units by id
func _sort_by_id(a,b):
	if a.unit_id > b.unit_id:
		return true
	return false


## Get position from formation
func _columns_formation(unit: Unit_Base):
	var position = units.find(unit)
	if position == -1:
		push_error("unit not in formation")
		return
	@warning_ignore("integer_division")
	return Vector3(fmod(position,formation_size)*unit.unit_radius*2.5,0,int(round(position/formation_size)*unit.unit_radius*2.5))
