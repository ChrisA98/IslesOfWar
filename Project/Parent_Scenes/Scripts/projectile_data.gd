extends Resource

class_name Projectile_Data

@export var travel_speed: float
@export var lifespan: float
@export var arc_height:float
@export var impact_particle_material:ParticleProcessMaterial
@export var impact_particle : Mesh
@export var projectile_mesh : Mesh

func _init(p_lifespan = 0.0, p_trvl_speed = 0.0, p_arc_height = 0.0, p_mat = null, p_mesh = null, imp_mesh = null):
	travel_speed = p_trvl_speed
	lifespan = p_lifespan
	arc_height = p_arc_height
	impact_particle_material = p_mat
	projectile_mesh = p_mesh
	impact_particle = imp_mesh
