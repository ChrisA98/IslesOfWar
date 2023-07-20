extends Node3D

var unit_models := {}


func _ready():
	## Prepare unit models list and add raycasts
	for i in get_children():
		var r = RayCast3D.new()
		r.position = i.position + (Vector3.UP*3.5)
		r.target_position = Vector3.DOWN*10
		r.set_collision_mask_value(1,false)
		r.set_collision_mask_value(16,true)
		add_child(r)
		unit_models[i] = r


## Snap unit models to ground
func snap_to_ground():
	for mod in unit_models:
		mod.position.y = clampf(unit_models[mod].get_collision_point().y - global_position.y,-2,2)


## Make units face target
func face_target(trgt):
	var lookdir = atan2(trgt.x, trgt.z)
	for i in unit_models:
		i.rotation.y = lerp(i.rotation.y, lookdir, 0.1)
