extends GPUParticles3D


func _body_exited(body):
	if body.has_method("set_following"):
		if(body.actor_owner.actor_ID == 0 ):
			emitting = false
