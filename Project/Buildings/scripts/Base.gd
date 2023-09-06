extends Building

@onready var valid_region = get_node("Valid_Region")
@onready var particles_generator = get_node("Valid_Region/GPUParticles3D")
@onready var radius = 30:
	set(value):
		radius = value
		_update_radius(value)

func _ready():
	super()
	pop_mod = 5	
	_update_radius(radius)


func load_data(data):
	super(data)
	set_radius_color(magic_color)


func set_pos(pos, _wait = false):
	super(pos, false)
	get_node("Valid_Region/GPUParticles3D").restart()
	if near_base(actor_owner.bases):
		make_invalid()


func place():
	_near_water()
	super()
	hide_radius()


func near_base(buildings) -> bool:
	if buildings == null:
		return false
	for b in buildings:
		if b == self:
			break
		if b.position.distance_to(position) < b.radius + radius:
			return true
	return false


## Check if base can build a dock
func _near_water():
	var near_w = false
	for i in range(36):
		var pos = Vector3()
		var alpha = (i*10)
		var x = radius * cos(alpha)
		var z = radius * sin(alpha)
		var elevation = world.world.get_loc_height(position+Vector3(x,0,z))
		if elevation <= world.world.water_table:
			near_w = true
			break
	print(near_w)
		


func preview_radius():
	valid_region.visible = true


func hide_radius():
	valid_region.visible = false


func _update_radius(new_radius):
	var m = CylinderMesh.new()
	m.set_bottom_radius(new_radius-.025)
	m.set_cap_bottom(false)
	m.set_top_radius(new_radius) 
	m.set_cap_top(false)
	m.set_height(1.5)
	m.surface_set_material(0,particles_generator.get_draw_pass_mesh(0).surface_get_material(0))
	particles_generator.set_draw_pass_mesh(0,m)


## Set color of radius
func set_radius_color(hex):
	var mat = particles_generator.get_draw_pass_mesh(0).surface_get_material(0)
	mat.albedo_color = hex
	particles_generator.get_draw_pass_mesh(0).surface_set_material(0,mat)
