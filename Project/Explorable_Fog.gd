extends GPUParticles3D


func enable_fog(state:bool = true):
	emitting = state
	$Area3D.monitoring = state


func _body_exited(body):
	if body.has_method("set_following"):
		if(body.actor_owner.actor_ID == 0 ):
			enable_fog(false)


func _area_entered(area):
	if area.has_meta("fog_owner_id"):
		if(area.get_meta("fog_owner_id") == 0):
			enable_fog(false)

