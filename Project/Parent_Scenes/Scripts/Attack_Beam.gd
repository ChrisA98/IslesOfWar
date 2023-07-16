extends Node3D

signal done_firing

@export var beam_data : Beam_Data

var damage: float
var damage_type: String
var target_location: Vector3

var refresh_rate = 0.1 ## Time between damage pulses

@onready var pulse_timer = $Pulse_Timer
@onready var beam_timer = $Beam_Duration
@onready var beam = $Attack_Beam
@onready var beam_visual = $Beam_Visual
@onready var particle_emitter = $HitParticles

func _ready():
	pulse_timer.timeout.connect(_pulse_beam)
	beam_timer.timeout.connect(end_beam)
	beam.shape.radius = beam_data.radius
	particle_emitter.process_material = beam_data.impact_particle_material
	particle_emitter.draw_pass_1 = beam_data.impact_particle
	beam_visual.mesh = beam_data.beam_mesh
	beam_visual.mesh.top_radius = beam_data.radius*.9
	beam_visual.mesh.bottom_radius = beam_data.radius



## Fire beam
func begin_firing(origin:Vector3, dmg:float, dmg_type:String, trgt:Vector3):
	position += origin
	damage = dmg*refresh_rate
	damage_type = dmg_type
	target_location = trgt
	
	_pulse_beam()
	
	beam.enabled = true
	visible = true
	pulse_timer.start(refresh_rate)
	beam_timer.start(beam_data.lifespan)
	


## End Beam early
func end_beam():
	beam_timer.stop()
	pulse_timer.stop()
	beam.enabled = false
	visible = false
	queue_free()


## Do damage to collisions with beam
func _pulse_beam():
	var coll = _fire_beam()
	pulse_timer.start(refresh_rate)
	
	var norm = beam.target_position.normalized()
	var cosa = Vector3.UP.dot(norm)
	var alph = acos(cosa)
	var axis = Vector3.UP.cross(norm).normalized()
	if(axis.is_normalized()):
		beam_visual.transform = transform.rotated(axis,alph)
		beam_visual.position = ((beam.target_position)/2) * position.direction_to(beam.target_position)
		beam_visual.mesh.height = position.distance_to(beam.target_position)*.9
	
	particle_emitter.position = (position.distance_to(beam.target_position) * position.direction_to(beam.target_position))
	particle_emitter.process_material.direction = beam.target_position.direction_to(beam.position)
	
	if coll == null:
		## No Collsiion, this shouldn't happen
		visible = false
		return
		
	beam_visual.mesh.height = global_position.distance_to(beam.get_collision_point(0))
	beam_visual.position = (global_position.distance_to(beam.get_collision_point(0))/2) * Vector3.ZERO.direction_to(beam.target_position)
	particle_emitter.position = (global_position.distance_to(beam.get_collision_point(0)) * Vector3.ZERO.direction_to(beam.target_position))
	
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
	## Basic Beam
	beam.target_position = target_location
	beam.force_shapecast_update()
	if (beam.is_colliding()):
		return beam.get_collider(0)
	
	## Old Penetrating code | Maybe reimplement later
	
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
	
