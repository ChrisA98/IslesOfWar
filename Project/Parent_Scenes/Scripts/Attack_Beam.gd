@tool
extends Node3D

@export var beam_data : Beam_Data
@export var test_trgt : Vector3

var damage: float
var damage_type: String
var target_location: Vector3

@onready var beams = [$Attack_Beam]

func _ready():
	pass


func _process(_delta):
	_create_beam(beams[0],test_trgt,true)

## Fire beam
func fire(dmg:float, dmg_type:String, trgt:Vector3):
	damage = dmg
	damage_type = dmg_type
	target_location = trgt
	
	_create_beam(beams[0],target_location)
	beams[0].force_shapecast_update()
	
	beams[0].enabled = true	


## End Beam early
func end_beam():
	pass


## Create Beam
func _create_beam(_beam,trgt,clear:=false):
	if clear:
		for i in range(1,beams.size()-1):
			beams[i].free()
			
	## Basic Beam
	look_at(trgt,Vector3.UP)
	_set_beam(_beam,trgt)
	
	if beam_data.penetration == -1 or beams.size() >= beam_data.penetration or _beam.get_collision_count() < 0:
		## Dont worry about penetrations\
		return
	var b_new = _beam.duplicate()
	_beam.position = _beam.get_collision_point(0)
	beams.push_back(b_new)
	_create_beam(b_new,trgt)

func _set_beam(_beam, trgt):
	_beam.target_position = trgt
	_beam.force_shapecast_update()
	
