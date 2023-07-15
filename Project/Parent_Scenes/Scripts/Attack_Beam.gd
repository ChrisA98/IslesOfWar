@tool
extends Node3D

@export var beam_data : Beam_Data
@export var test_trgt : Vector3
@export var shoot: bool:
	set(value):
		shoot = value
		if value:
			target_location = test_trgt
			_pulse_beam()

var damage: float
var damage_type: String
var target_location: Vector3

var refresh_rate = 0.1 ## Time between damage pulses

@onready var pulse_timer = $Pulse_Timer
@onready var beam_timer = $Beam_Duration
@onready var beam = $Attack_Beam
@onready var beam_visual = $Beam_Visual

func _ready():
	pulse_timer.timeout.connect(_pulse_beam)
	beam_timer.timeout.connect(end_beam)
	beam.shape.radius = beam_data.radius
	beam_visual.mesh = beam_data.beam_mesh
	beam_visual.mesh.top_radius = beam_data.radius
	beam_visual.mesh.bottom_radius = beam_data.radius



## Fire beam
func begin_firing(dmg:float, dmg_type:String, trgt:Vector3):
	damage = dmg
	damage_type = dmg_type
	target_location = trgt
	
	_pulse_beam()
	
	beam.enabled = true
	pulse_timer.start(refresh_rate)
	beam_timer.start(beam_data.lifespan)
	


## End Beam early
func end_beam():
	pulse_timer.stop()


## Do damage to collisions with beam
func _pulse_beam():
	var coll = _fire_beam()
	pulse_timer.start(refresh_rate)
	if coll == null:
		## No Collsiion, this shouldn't happen
		return
	
	beam_visual.position = (position.distance_to(coll.position)/2) * position.direction_to(coll.position)
	beam_visual.mesh.height = position.distance_to(coll.position)
	beam_visual.look_at(coll.position,Vector3.UP)
	beam_visual.rotate_x(-180)
	
	## Check for unit hit
	if(coll.has_method("damage") and coll != get_parent()):
		coll.damage(damage,damage_type)
		return
	## Check for building hit
	if(coll.get_parent().has_method("damage")):
		coll.get_parent().damage(damage,damage_type)
		return
	## Check for ground hit
	if(coll.has_meta("is_ground")):
		pass


## Create Beam
func _fire_beam():
	shoot = false
	## Basic Beam
	beam.target_position = target_location
	beam.force_shapecast_update()
	if (beam.is_colliding()):
		return beam.get_collider(0)
	
	#if beam_data.penetration == -1 or beams.size() >= beam_data.penetration or !_beam.is_colliding():
	#	## Dont worry about penetrations\
	#	return
	#var b_new = _beam.duplicate(true)
	#b_new.position = (position.distance_to(_beam.get_collision_point(0))*trgt.normalized())-b_new.position
	#beams.push_back(b_new)
	#_beam.add_child(b_new)
	#_set_beam(b_new,Vector3.UP)
	#_create_beam(b_new,trgt-b_new.position)


## Set Beam characteristics
func _set_beam(_beam, trgt):
	_beam.target_position = trgt
	_beam.force_shapecast_update()
	
