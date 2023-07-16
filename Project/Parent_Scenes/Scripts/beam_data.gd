extends Resource
class_name Beam_Data

## Make Penetration -1 for no limit
@export var radius : = .25 ## Radius of beam
@export var lifespan: float
@export var impact_particle_material:ParticleProcessMaterial
@export var impact_particle : Mesh
@export var beam_mesh : Mesh

func _init(_radius:= 0.25, p_lifespan = 0.0, p_mat = null, p_mesh = null, imp_mesh = null):
	lifespan = p_lifespan
	impact_particle_material = p_mat
	beam_mesh = p_mesh
	impact_particle = imp_mesh
	radius = _radius
