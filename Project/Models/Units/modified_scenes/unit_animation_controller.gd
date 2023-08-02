@tool
extends MultiMeshInstance3D
class_name unit_animator

## IDLE CONSTANTS
const IDLE= ["idle",0, 59]

## WALKING CONSTANTS
const WALK= ["walk",60, 119]

## BASE ATTACK CONSTANTS
const ATTACK_01 = ["attack_01",130, 159]

## SECONDARY ATTACK CONSTANTS
const ATTACK_02 = ["attack_02",160, 189]

@export var test :bool = false:
	set(value):
		for i in range(1):
			_spawn_unit_instance(Vector3(randf() * 100 - 50, 0, randf() * 50 - 25),color)

@export var color : Color

@export var walk :bool = false:
	set(value):
		for i in range(1):
			_set_animation_window(randi_range(0,active_units-1),WALK[0])

@export var idle :bool = false:
	set(value):
		for i in range(1):
			_set_animation_window(randi_range(0,active_units-1),IDLE[0])

@export var attack :bool = false:
	set(value):
		for i in range(1):
			_set_animation_window(randi_range(0,active_units-1),ATTACK_01[0])

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
func _spawn_unit_instance(pos: Vector3, accent_color : Color):
	## Spawn new unit
	active_units += 1
	units.set_visible_instance_count(active_units)
	units.set_instance_color(active_units,accent_color)
	_move_unit_instance(active_units,pos)
	_set_animation_window(active_units,"idle")


## Change instance animation by moving animation window
func _set_animation_window(unit: int,animation: String):
	match(animation):
		IDLE[0]:
			units.set_instance_custom_data(unit,Color(IDLE[1], IDLE[2], 0, 0))
		WALK[0]:
			units.set_instance_custom_data(unit,Color(WALK[1], WALK[2], 0, 0))
		ATTACK_01[0]:
			units.set_instance_custom_data(unit,Color(ATTACK_01[1], ATTACK_01[2], 0, 0))


## Move target instance to new position
func _move_unit_instance(unit: int, trgt_pos: Vector3):
	var trans = Transform3D()
	trans = trans.translated(trgt_pos)
	units.set_instance_transform(unit,trans)
	
