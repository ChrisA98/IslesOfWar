extends Building

@export var radius = 30:
	set(value):
		radius = value
		if is_node_ready():
			_update_radius(value)

# Variables for AI dock placement
var can_make_dock : bool
var water_loc: Vector3

var building_child : Building

@onready var valid_region = get_node("Valid_Region")
@onready var particles_generator = get_node("Valid_Region/GPUParticles3D")

func _ready():
	super()
	pop_mod = 5	
	_update_radius(radius)
	attack_manager.call_deferred("init",attack_manager.attack_type.RANGE_PROJ, .125, 0, "damage_type")
	attack_manager.add_collision_exception($StaticBody3D)


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
	## Adopt orphan buildings nearby
	for bldg in _get_nearby_orphan_buildings():
		bldg.parent_base = self
		bldg.parent_building = self
		children_buildings.push_back(bldg)
		actor_owner.update_grass_tex(bldg)
	hide_radius()
	building_child = self


func finish_building():
	super()
	building_child = null

func near_base(buildings) -> bool:
	if buildings == null:
		return false
	for b in world.world_buildings:
		if b == self or !b.has_method("_near_water"):
			continue
		if b.position.distance_to(position) < b.radius + radius:
			return true
	return false


## Check if base can build a dock
func _near_water():
	var near_w = false
	var lowest = [Vector3(),9999]
	for i in range(36):
		var alpha = (i*10)
		var x = radius * cos(alpha)
		var z = radius * sin(alpha)
		var pos = Vector3(x,0,z)
		var elevation = world.world.get_loc_height(position)	
		if elevation <= lowest[1]:
			lowest = [pos,elevation]
	
	if lowest[1] <= world.world.water_table:
		near_w = true
	can_make_dock = near_w
	water_loc = lowest[0]


func preview_radius():
	valid_region.visible = true


func hide_radius():
	valid_region.visible = false


func delayed_delete():
	actor_owner.bases.erase(self)
	for i in children_buildings:
		if i.is_building:
			i.delayed_delete()
	await get_tree().physics_frame
	super()


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


## Get any nearby buildings owned by owning actor and not connected to a base
## that aren't other bases
func _get_nearby_orphan_buildings():
	var out_arr = []
	for b in actor_owner.buildings:
		if position.distance_to(b.position) > radius or b.parent_base != actor_owner:
			continue
		if b.has_method("set_radius_color"):
			continue
		out_arr.push_back(b)
	return out_arr
