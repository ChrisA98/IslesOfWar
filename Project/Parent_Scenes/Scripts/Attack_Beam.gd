@tool
extends ShapeCast3D

@export var beam_data : Beam_Data
@export var test_trgt : Vector3

var damage: float
var damage_type: String
var target_location: Vector3

func _ready():
	pass


func _process(_delta):
	_create_beam(test_trgt)

## Fire beam
func fire(dmg:float, dmg_type:String, trgt:Vector3):
	damage = dmg
	damage_type = dmg_type
	target_location = trgt
	
	_create_beam(target_location)
	
	enabled = true	


## End Beam early
func end_beam():
	pass


## Create Beam
func _create_beam(trgt):
	## Basic Beam	
	target_position.z = -(position.distance_to(trgt)/2)
	shape.size.z = position.distance_to(trgt)
	look_at(trgt,Vector3.UP)
	force_shapecast_update()
	
	if beam_data.penetration == -1:
		## Dont worry about penetrations
		return
	## Worry about Penetrations
	while get_collision_count() > beam_data.penetration:
		trgt = get_collision_point(get_collision_count()-1)
		target_position.z = -(position.distance_to(trgt)/2)
		shape.size.z = position.distance_to(trgt)
		look_at(trgt,Vector3.UP)
		force_shapecast_update()
	

