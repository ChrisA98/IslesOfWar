@tool
extends Path3D

signal target_hit

@export var proj_data : Projectile_Data
 
var travel_speed : float
var lifespan : float
var damage: float
var damage_type: String
var collision_exceptions = []

var projectiles : Array

func _ready():
	call_deferred("_load_data")


func _physics_process(delta):
	for proj in projectiles:
		proj.progress += (travel_speed*delta)
		proj.get_child(1).force_shapecast_update() ## Guess I need to forcibly update the shapecast
		for i in proj.get_child(1).get_collision_count():
			_proj_collided(proj.get_child(1).get_collider(i), proj)
		if(proj.progress_ratio >= 1):
			## Projectile hit end of lifespan
			call_deferred("_destroy_projectile",proj, true)


## Fire a projectile
func fire(pos:Vector3, trgt:Vector3, _range: float, _damage: float, damage_typ: String):
	_load_data()
	damage = _damage
	damage_typ = damage_typ
	position = pos
	var dir = position.direction_to(trgt)
	_generate_arc(dir, _range, proj_data.arc_height)
	projectiles.push_back(_generate_projectile())
	@warning_ignore("integer_division") projectiles.back().set_progress_ratio(1/15) ## Gets projectile to first point


## Load projectile data
func _load_data():
	travel_speed = proj_data.travel_speed
	lifespan = proj_data.lifespan


## Projectile dies
func _destroy_projectile(projectile, got_old:bool = false):
	if !got_old:
		projectile.get_child(2).emitting = true
	projectile.get_child(0).visible = false
	projectiles.erase(projectile)
	await get_tree().create_timer(1).timeout
	if(is_instance_valid(projectile)):
		projectile.queue_free()
	if projectiles.size() == 0:
		## Arc is now empty
		queue_free()


## Projectile collided with objects
func _proj_collided(hit_trgt: Node3D,proj):
	if collision_exceptions.has(hit_trgt) or hit_trgt == null:
		## ignore these ones
		return
	## Check for unit hit
	if(hit_trgt.has_method("damage") and hit_trgt != get_parent()):
		call_deferred("_destroy_projectile",proj)
		hit_trgt.damage(damage,damage_type)
		return
	## Check for building hit
	if(hit_trgt.get_parent().has_method("damage")):
		call_deferred("_destroy_projectile",proj)
		hit_trgt.get_parent().damage(damage,damage_type)
		return
	## Check for ground hit
	if(hit_trgt.has_meta("is_ground")):
		call_deferred("_destroy_projectile",proj)


## Create a projectile with loaded data
func _generate_projectile() -> PathFollow3D:
	var proj_out = PathFollow3D.new()
	proj_out.rotation_mode = PathFollow3D.ROTATION_ORIENTED
	proj_out.loop = false
	
	## Create projectile mesh
	var p_mesh = MeshInstance3D.new()
	p_mesh.mesh = proj_data.projectile_mesh
	p_mesh.rotate_x(deg_to_rad(-90))
	proj_out.add_child(p_mesh)
	
	## Create Detection area
	var coll_shape = ShapeCast3D.new()
	coll_shape.shape = SphereShape3D.new()
	coll_shape.rotate_x(deg_to_rad(-90))
	coll_shape.max_results = 8
	coll_shape.set_collision_mask_value(1, false)
	coll_shape.set_collision_mask_value(3, true)
	coll_shape.set_collision_mask_value(4, true)
	coll_shape.set_collision_mask_value(16, true) #ground
	coll_shape.shape.radius = 0.75
	proj_out.add_child(coll_shape)
	
	## Create Particle emitter
	var emitter = GPUParticles3D.new()
	emitter.amount = 200
	emitter.one_shot = true
	emitter.emitting = false
	emitter.explosiveness = 1
	emitter.process_material = proj_data.impact_particle_material
	emitter.draw_pass_1 = proj_data.impact_particle
	proj_out.add_child(emitter)
	
	add_child(proj_out)
	
	return proj_out


## Old Generate Arc
## DEPRECATED - old arc generating code. Honestly pretty bad. What was I thinking??
#func _generate_arc(direction:Vector3, _range:float, arc_height:float):
#	var lookdir = atan2(direction.x, direction.z)
#	rotation.y = lookdir
#	curve.clear_points()
#	var forward_vec : Vector3
#	var _in := Vector3.ZERO
#	var pos : Vector3 = Vector3(0,sin(0)*arc_height,_range*((0)/PI))
#	var _out : Vector3 = Vector3(0,sin(0)*arc_height,_range*((1)/PI))
#	for i in range(1,5):
#		_in = pos - Vector3(0,0,_range*((1)/PI))
#		pos = _out - Vector3(0,0,_range*((1)/PI))
#		_out = Vector3(0,sin(i)*arc_height,_range*((i+1)/PI))
#		curve.add_point(pos,_in.normalized(),_out.normalized())
#	_out = Vector3(0,(sin(4)*arc_height)*arc_height,_range*(5/PI))
#	curve.set_point_out(0, Vector3(0,curve.get_point_out(0).y*-1,curve.get_point_out(0).z))
#	curve.set_point_in(1, Vector3(0,2,-1))
#	curve.set_point_out(2, _out)
#	forward_vec = pos.direction_to(_out)+ (Vector3.DOWN*.5)
#	for i in range(1,5):
#		_in = (_in + forward_vec*PI).direction_to(pos)
#		pos = pos + forward_vec*PI
#		_out = forward_vec*PI
#		forward_vec = pos.direction_to(pos + _out)+ (Vector3.DOWN*.5)
#		curve.add_point(pos,_in,_out)

func _generate_arc(direction:Vector3, _range:float, arc_height:float):
	curve.clear_points()
	var p0 = Vector3.ZERO
	var p1 = (direction*_range/2) +Vector3(0,arc_height,0)
	var p2 = direction*_range
	
	var resolution = 10
	
	for i in range(-1,resolution+4):
		##Get progress points
		@warning_ignore("integer_division") var t_i = (i-1)/(resolution)
		@warning_ignore("integer_division") var t = float(i)/(resolution)
		@warning_ignore("integer_division") var t_o = (i+1)/(resolution)
				
		## Get points ojn line for progress points
		var pos_i = (p0.lerp(p1,t)).lerp(p1.lerp(p2,t), t_i)
		var pos = (p0.lerp(p1,t)).lerp(p1.lerp(p2,t), t)
		var pos_o = (p0.lerp(p1,t)).lerp(p1.lerp(p2,t), t_o)
		
		curve.add_point(pos,pos.direction_to(pos_i),pos.direction_to(pos_o))
