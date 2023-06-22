extends GPUParticles3D

var neighbors = []
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


func disable_isolated():
	var isolated = emitting
	for n in neighbors:
		if !n.emitting:
			isolated = false
			break
	if isolated:
		$Area3D.set_deferred("monitoring",false)
		$Area3D.set_deferred("monitorable",false)


func enable_fog(state:bool = true):
	emitting = state
	$Area3D.set_deferred("monitoring",state)	


func _body_exited(body):
	if body.has_method("set_following"):
		if(body.actor_owner.actor_ID == 0 ):
			enable_fog(false)
			for n in neighbors:
				if n.emitting:
					n.enable_fog()


func _area_entered(area):
	if area.has_meta("fog_owner_id"):
		if(area.get_meta("fog_owner_id") == 0):
			enable_fog(false)
			for n in neighbors:
				if n.emitting:
					n.enable_fog()

