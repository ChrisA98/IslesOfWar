extends GPUParticlesCollisionSphere3D

var fog_break_radius: float = 25:
	get:
		return fog_break_radius
	set(value):
		fog_break_radius = value
		radius = value
		$Area3D/CollisionShape3D.shape.radius = value

@onready var detect_area = $Area3D

## Active state of fog_breaker
var active : bool = false:
	get:
		return active
	set(value):
		active = value
		set_layer_mask(1)


## Activate the area
func activate_area():
	detect_area.monitorable = true
	detect_area.monitoring = true
