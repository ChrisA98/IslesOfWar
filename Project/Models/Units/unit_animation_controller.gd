@tool
extends MultiMeshInstance3D
class_name unit_animator

signal unit_reordered(master, old_id, new_id)

enum instance_targets {START_FRAME,END_FRAME,ANIM_START_TIME,ANIM_OFFSET}

@export var preview_unit : bool:
	set(value):
		if !Engine.is_editor_hint():
			return
		preview_unit = value
		if value :
			spawn_unit_instance(Vector3.ZERO,Color.BLUE)
			_set_animation_window(0,IDLE[0])
			return
		delete_unit(1)
@export var rotation_offset : float
## IDLE CONSTANTS
const IDLE= ["idle",0, 59]

## WALKING CONSTANTS
const WALK= ["walk",60, 119]

## BASE ATTACK CONSTANTS
## maximum 2 sec attack animation
const ATTACK_01 = ["attack_1",130, 189]

## SECONDARY ATTACK CONSTANTS
## maximum 2 sec attack animation
const ATTACK_02 = ["attack_2",190, 249]

## Attacking idle animation
const IDLE_ATTACKING= ["idle_attacking",250, 310]


@export var max_instances = 1024

var active_units = 0
var active_animation : String

@onready var units = multimesh
@export var model_name: String

func _ready():	
	units.set_instance_count(0)
	active_units = 1
	units.set_use_custom_data(true)
	units.set_use_colors(true)
	units.set_instance_count(max_instances)
	units.set_visible_instance_count(active_units)


## Spawn a new unit instane at target location
func spawn_unit_instance(pos: Vector3, accent_color : Color):
	## Spawn new unit
	active_units += 1
	units.set_visible_instance_count(active_units)
	units.set_instance_color(active_units-1,accent_color)
	var trans = Transform3D().translated(pos)
	units.set_instance_transform(active_units-1,trans)
	set_animation_state(active_units-1,"idle")
	return active_units-1


## Set base animation state
func set_animation_state(unit: int, anim:String):
	active_animation = anim
	_set_animation_window(unit,anim)


## Play single animation and return to active animation
func burst_animation(unit: int, anim:String, duration_sec: float):
	_set_animation_window(unit,anim)
	call_deferred("_burst_animation_helper",unit,duration_sec)


## deferred call so await can be used with an easier call to burt animation
func _burst_animation_helper(unit:int, duration: float):
	await get_tree().create_timer(duration).timeout
	_set_animation_window(unit,active_animation)


## Move target instance to new position
func move_unit_instance(unit: int, trgt_pos: Vector3, t_basis):
	var trans = t_basis
	## Erase y value so the shader can handle that
	trgt_pos.y = 0
	trans.origin = trgt_pos
	units.set_instance_transform(unit,trans)


## Get current transform rotation from basis
func get_unit_basis(unit: int):
	return units.get_instance_transform(unit)


## Rotate instance to target location
func face_unit_instance(unit: int, trgt_pos: Vector3, m_trans: Transform3D):
	var pos = m_trans.origin
	var trgt_vector = pos.direction_to(trgt_pos)
	var lookdir = atan2(trgt_vector.x, trgt_vector.z)
	
	var initial = m_trans.basis.get_rotation_quaternion()
	var trans = Transform3D()
	trans.origin = pos
	var final = trans.rotated(Vector3.UP,lookdir).basis.get_rotation_quaternion()
	var out_q = initial.slerp(final,0.1)
	
	trans.basis = Basis(out_q)
	units.set_instance_transform(unit,trans)


## Hide unit from view
func hide_unit(unit: int, col : Color, state : bool = true):	
	var unit_color = col
	if state:
		unit_color.a = 0
	else:
		unit_color.a = 1
	units.set_instance_color(unit,unit_color)


## Shift last unit to target units place and transfer data
func delete_unit(unit: int):
	if unit == active_units:
		active_units -= 1
		units.set_visible_instance_count(active_units)
		return
	var end_data = units.get_instance_custom_data(active_units-1)
	var end_color = units.get_instance_color(active_units-1)
	var end_trans = units.get_instance_transform(active_units-1)
	units.set_instance_custom_data(unit,end_data)
	units.set_instance_color(unit,end_color)
	units.set_instance_transform(unit,end_trans)
	
	## Signal that the last unit is now in the target units place
	unit_reordered.emit(self, active_units-1, unit)
	
	active_units-=1
	units.set_visible_instance_count(active_units)
	units.set_instance_transform(unit,end_trans)


## Change instance animation by moving animation window
func _set_animation_window(unit: int,animation: String):
	var time = Time.get_ticks_msec()/1000.0
	match(animation):
		IDLE[0]:
			units.set_instance_custom_data(unit,Color(IDLE[1], IDLE[2], time, randf()))
		WALK[0]:
			units.set_instance_custom_data(unit,Color(WALK[1], WALK[2], time, randf()))
		ATTACK_01[0]:
			units.set_instance_custom_data(unit,Color(ATTACK_01[1], ATTACK_01[2], time, 0))
		IDLE_ATTACKING[0]:
			units.set_instance_custom_data(unit,Color(IDLE_ATTACKING[1], IDLE_ATTACKING[2], time, randf()))
