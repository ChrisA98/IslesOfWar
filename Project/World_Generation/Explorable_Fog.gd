extends GPUParticles3D

var neighbors = []
var isolated = true
@onready var neighbor_raycasts = [
	get_node("neighbor_reader_x+"),
	get_node("neighbor_reader_x-"),
	get_node("neighbor_reader_z+"),
	get_node("neighbor_reader_z-")]

## Assign neighbors by reading raycast collisions
func get_neighbors():
	for ray in neighbor_raycasts:
		neighbors.push_back(ray.get_collider().get_parent())
		ray.queue_free()
	#if($Area3D.get_overlapping_bodies().size() > 1 and !$Area3D.get_overlapping_bodies()[1].name.contains("Floor")):
		#queue_free()


func disable_isolated():
	for i in neighbors:
		if !is_instance_valid(i) or i.is_queued_for_deletion():
			isolated = false
	if isolated:
		$Area3D.set_deferred("monitoring",false)
		$Area3D.set_deferred("monitorable",false)


func enable_fog(state:bool = true):
	emitting = state
	$Area3D.set_deferred("monitoring",state)
	$Area3D.set_deferred("monitorable",state)


func _body_exited(body):
	if !body.has_method("set_following"):
		return
	if(body.actor_owner.actor_ID != 0 ):
		return
	enable_fog(false)
	for n in neighbors:
		if is_instance_valid(n) and isolated:
			n.enable_fog()


func _body_entered(body):
	if body.has_meta("fog_owner_id"):
		if(body.get_meta("fog_owner_id") == 0):
			for n in neighbors:
				if is_instance_valid(n) and n.emitting:
					n.enable_fog()
					isolated = false


func _area_entered(area):
	if area.has_meta("fog_owner_id"):
		if(area.get_meta("fog_owner_id") == 0):
			enable_fog(false)

