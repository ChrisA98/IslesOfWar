extends MultiMeshInstance3D
class_name unit_animator

signal unit_reordered(old_id,new_id)

enum instance_targets {START_FRAME,END_FRAME,LIVING_STATE,_OPEN}

## IDLE CONSTANTS
const IDLE= ["idle",0, 59]

## WALKING CONSTANTS
const WALK= ["walk",60, 119]

## BASE ATTACK CONSTANTS
const ATTACK_01 = ["attack_01",130, 159]

## SECONDARY ATTACK CONSTANTS
const ATTACK_02 = ["attack_02",160, 189]

var active_units = 0

@onready var units = multimesh

func _ready():	
	units.set_instance_count(0)
	active_units = 0
	units.set_use_custom_data(true)
	units.set_use_colors(true)
	units.set_instance_count(1028)
	units.set_visible_instance_count(0)


## Spawn a new unit instane at target location
func spawn_unit_instance(pos: Vector3, accent_color : Color):
	## Spawn new unit
	active_units += 1
	units.set_visible_instance_count(active_units)
	units.set_instance_color(active_units-1,accent_color)
	move_unit_instance(active_units-1,pos)
	set_animation_window(active_units-1,IDLE[0])


## Change instance animation by moving animation window
func set_animation_window(unit: int,animation: String):
	match(animation):
		IDLE[0]:
			units.set_instance_custom_data(unit,Color(IDLE[1], IDLE[2], 1, 0))
		WALK[0]:
			units.set_instance_custom_data(unit,Color(WALK[1], WALK[2], 1, 0))
		ATTACK_01[0]:
			units.set_instance_custom_data(unit,Color(ATTACK_01[1], ATTACK_01[2], 1, 0))


## Move target instance to new position
func move_unit_instance(unit: int, trgt_pos: Vector3):
	var trans = Transform3D()
	trans = trans.translated(trgt_pos)
	units.set_instance_transform(unit,trans)


## Rotate instance to target location
func face_unit_instance(unit: int, trgt_pos: Vector3):
	var pos = units.get_instance_transform(unit).origin
	var trgt_vector = pos.direction_to(trgt_pos)
	var lookdir = atan2(trgt_vector.x, trgt_vector.z)
	
	var initial = Quaternion(units.get_instance_transform(unit).basis)
	var trans = Transform3D()
	trans.origin = pos
	var final = Quaternion(trans.rotated(Vector3.UP,lookdir).basis)
	var out_q = initial.slerp(final,0.1)
	
	trans.basis = Basis(out_q)
	units.set_instance_transform(unit,trans)


## Hide unit from view
func hide_unit(unit: int, state : bool = true):	
	var unit_color = units.get_instance_color(unit)
	if state:
		unit_color.a = 0
	else:
		unit_color.a = 1
	units.set_instance_color(unit,unit_color)


## Shift last unit to target units place and transfer data
func delete_unit(unit: int):
	var end_data = units.get_instance_custom_data(active_units-1)
	var end_color = units.get_instance_color(active_units-1)
	var end_trans = units.get_instance_transform(active_units-1)
	units.set_instance_custom_data(unit,end_data)
	units.set_instance_color(unit,end_color)
	units.set_instance_transform(unit,end_trans)
	active_units-=1
	units.set_visible_instance_count(active_units)
	## Signal that the last unit is now in the target units place
	unit_reordered.emit(active_units,unit)
