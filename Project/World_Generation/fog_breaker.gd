extends GPUParticlesCollisionSphere3D

var fog_break_radius: float = 25:
	get:
		return fog_break_radius
	set(value):
		fog_break_radius = value
		radius = value
		$Area3D/CollisionShape3D.shape.radius = value
