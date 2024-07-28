extends Node3D

signal loaded

''' Time keeping vars '''
@export var use_random_base_spawns := false
@export_group("Time")
@export var year_day = 270
@export var year = 603
@export var day_cycle = true
@export_group("Terrain")
@export var meshres = 5
@export var terrain_amplitude = 100
@export var water_table : float = 7
@export var heightmap_dir: String = "res://Test_Items/Map_data/"
@export_group("Fog Data")
@export_range(0,1) var fog_darkness := 0.7

''' Time keeping vars '''
var sun_rotation = 0
var moon_rotation = 0
var sun_str = 1.3
var moon_str = .427

var heightmap
var rng = RandomNumberGenerator.new()
var height_data = {}
var vertices = PackedVector3Array()
var UVs = PackedVector2Array()
var normals = PackedVector3Array()
var map_offset: float

## Local stored copy of the building_loc texture
## r = building - hides trees and ground scatter
## g = elevation - lower ground  
## b = 
## format - RGBF
var building_locations = Image.new()

var gamescene: Node3D
@onready var sun = $Sun
@onready var moon = $Moon
var noise_image: Image = Image.new()
var chunk_size = 500
var chunks: int
var nav_manager
@onready var ground: MeshInstance3D = get_node("../Player/Visual_Ground")
@onready var water = get_node("../Player/Visual_Ground/Water")
var fog_material = ShaderMaterial.new()

var editor_version = true


func init(_gamescene):
	print("using new script")
	editor_version = false
	gamescene = _gamescene
	Global_Vars.load_text = ("loading level")
	fog_material.set_shader(load("res://Materials/fog_of_war_overlay.gdshader"))
	
	Global_Vars.load_text = ("loaded shader")
	@warning_ignore("integer_division") chunks = sqrt(find_files())
	heightmap = Image.load_from_file(heightmap_dir+"master.png")
	if heightmap.is_compressed():
		heightmap.decompress()
	Global_Vars.heightmap = heightmap
	RenderingServer.global_shader_parameter_set("heightmap_tex",ImageTexture.create_from_image(heightmap))
	Global_Vars.heightmap_size = chunks*500
	Global_Vars.load_text = ("loaded heightmap _ chunks = "+str(chunks))
	
	##Set up buildings tex
	building_locations = Image.create(chunks*chunk_size,chunks*chunk_size,false,Image.FORMAT_RGBF)
	Global_Vars.load_text = "Loaded Buildings Texture"
	building_locations.fill(Color.BLACK)
	RenderingServer.global_shader_parameter_set("building_locs",ImageTexture.create_from_image(building_locations))
	Global_Vars.load_text = ("Loading map")
	nav_manager = load("res://World_Generation/NavMeshManager.gd")
	@warning_ignore("integer_division") map_offset = (chunk_size*chunks)/2
	
	## Prepare collision chunks
	for y in range(0,chunks):
		for x in range(0,chunks):
			var _img = Image.new()
			var __img = Image.load_from_file(heightmap_dir+"chunk_"+str(y)+"_"+str(x)+".png")
			_img = __img
			chunk_size = _img.get_width()
			build_map(_img, Vector3(x,0,y),Vector2i(x,y))
	
	
	## Assign Regions to terrain mesh chunks
	for i in get_children():
		if i.name.contains("Region"):
			i.get_child(0).get_child(0).input_event.connect(gamescene.ground_click.bind(i)) 
			i.get_child(0).transparency = 1 #hide terrain mesh
			i.get_child(0).get_child(0).set_collision_layer_value(16,true)
			i.get_child(0).get_child(0).set_collision_mask_value(16,true)
			i.get_child(0).get_child(0).set_meta("is_ground", true)
			i.set_nav_region()
	
	Global_Vars.load_text = ("loading fog")
	## Set fog global data
	RenderingServer.global_shader_parameter_set("fog_darkness",fog_darkness)
	RenderingServer.global_shader_parameter_set("heightmap_tex_size",Vector2(heightmap.get_width(),heightmap.get_width()))
	Global_Vars.load_text = ("heightmap size =  = "+str(heightmap.get_width()))
	
	## Set water Height Data
	RenderingServer.global_shader_parameter_set("water_depth",water_table)
	Global_Vars.water_elevation = water_table
	
	
	call_deferred("_build_fog_war")

func _ready():
	if editor_version:
		heightmap = Image.load_from_file(heightmap_dir+"master"+".png").get_image()
		Global_Vars.heightmap = heightmap
		return
		
	RenderingServer.global_shader_parameter_set("ground_tex_main",$Visual_Ground.mesh.surface_get_material(0).get_shader_parameter("grass_alb_tex"))
	
	Global_Vars.load_text = ("loading sun")
	# Set Sun and moon in place
	$Sun.rotation_degrees = Vector3(0,90,-180)
	$Moon.rotation_degrees = Vector3(0,90,-180)
	loaded.emit()
	get_parent().call_deferred("_prepare_game")

#region initializing Functions

## Prepare water navigation
func _prepare_water():
	await get_tree().create_timer(5).timeout ## Small timer to give ground locations to get into the generation queue first
	Global_Vars.load_text = ("loading water")
	var water_template = $Water/StaticBody3D
	#$Water/StaticBody3D/CollisionShape3D.shape.size = Vector3(Global_Vars.heightmap_size,1,Global_Vars.heightmap_size)
	$Water/StaticBody3D.position.y = water_table
	for y in range(0,chunks):
		for x in range(0,chunks):
			var region_mesh = find_child(StringName("Region_"+str(x) +"_"+ str(y)),false,false).get_child(0)
			var wtr_chunk = water_template.duplicate()
			region_mesh.add_child(wtr_chunk)
			wtr_chunk.input_event.connect(gamescene.ground_click.bind(wtr_chunk))
			## Offset to enter
			@warning_ignore("integer_division") wtr_chunk.position.z = -chunk_size/2
			@warning_ignore("integer_division") wtr_chunk.position.x = chunk_size/2
			## prepare Navigation Region
			var wtr_nav_region = NavigationRegion3D.new()
			wtr_nav_region.set_script(nav_manager)
			wtr_nav_region.finished_baking.connect(gamescene._navmesh_updated)
			wtr_nav_region.starting_baking.connect(gamescene._navmesh_update_start)
			wtr_nav_region.agent_max_slope = 10
			wtr_nav_region.add_to_group("water")
			#add to world
			region_mesh.add_child(wtr_nav_region)
			region_mesh.get_child(-1).set_name("water_navigation_"+str(x) +"_"+ str(y))	
			wtr_nav_region.set_nav_region()
			@warning_ignore("integer_division")
			wtr_nav_region.navigation_mesh.set_filter_baking_aabb(AABB(Vector3(0,water_table-2.5,-500),Vector3(chunk_size,10,chunk_size)))
			wtr_nav_region.navigation_mesh.agent_height = 6
			wtr_nav_region.navigation_mesh.agent_max_climb = 0
			wtr_nav_region.navigation_mesh.set_sample_partition_type(0)
			wtr_nav_region.update_navigation_mesh()
			wtr_nav_region.use_edge_connections = true
			wtr_nav_region.set_navigation_layer_value(1, false)
			wtr_nav_region.set_navigation_layer_value(2, true)
	$Water/StaticBody3D.queue_free()
			
	## Prepare Ground with level info
	ground.mesh.surface_get_material(0).set_shader_parameter("t_height", terrain_amplitude)
	## Prepare Water with level info
	water.mesh.surface_get_material(0).set_shader_parameter("t_height", terrain_amplitude)


func _build_fog_war():
	return
	## Fog of war walls
	@warning_ignore("integer_division") var fog_wall_size = ((chunk_size*chunks)/65)+1	#gets length of walls
	var base_fog_wall = $Great_Fog_Wall.find_children("Fog*","Node",false)[-1]
	@warning_ignore("integer_division") base_fog_wall.position.x = ((chunk_size*chunks)/2) + 65
	@warning_ignore("integer_division") base_fog_wall.position.z = ((chunk_size*chunks*-1)/2) - 65
	for j in range(fog_wall_size):
		var te = base_fog_wall.duplicate()
		te.position.x -= 65*j
		$Great_Fog_Wall.add_child(te)
	for j in range(fog_wall_size):
		var te = base_fog_wall.duplicate()
		te.position.z += 65*j
		$Great_Fog_Wall.add_child(te)
	for j in range(fog_wall_size+1):
		var te = base_fog_wall.duplicate()
		te.position.x -= 65*j
		@warning_ignore("integer_division") te.position.z = (chunk_size*chunks/2)+65
		$Great_Fog_Wall.add_child(te)
	for j in range(fog_wall_size+1):
		var te = base_fog_wall.duplicate()
		te.position.z += 65*j
		@warning_ignore("integer_division") te.position.x = -((chunk_size*chunks/2)+65)
		$Great_Fog_Wall.add_child(te)
	
	
	## Fog of war explorable
	var fog_explor_range = (chunk_size*chunks)/25	#gets length of walls
	var base_fog = $Explorable_Fog.find_children("Fog*","Node",false)[-1]
	@warning_ignore("integer_division") base_fog.position.x = ((chunk_size*chunks)/2) - 25
	@warning_ignore("integer_division") base_fog.position.z = ((chunk_size*chunks*-1)/2) + 25
	var picker = $Explorable_Fog/RayCast3D
	for i in range(fog_explor_range):
		for j in range(fog_explor_range):
			var te = base_fog.duplicate()
			te.position.x -= 25*j
			te.position.z += 25*i
			picker.position.x = te.position.x
			picker.position.z = te.position.z 
			picker.force_raycast_update()
			te.position.y = picker.get_collision_point().y
			$Explorable_Fog.add_child(te)
	
	
	await get_tree().create_timer(1).timeout
	
	## Assign fog network
	for fog in range(1,$Explorable_Fog.get_children().size()-1):
		$Explorable_Fog.get_children()[fog].get_neighbors()
	await get_tree().create_timer(1).timeout
	for fog in range(1,$Explorable_Fog.get_children().size()-1):
		$Explorable_Fog.get_children()[fog].get_child(0).set_deferred("monitorable",false)
	## isolate fog units
	#for fog in range(1,$Explorable_Fog.get_children().size()-1):
		#pass
		#$Explorable_Fog.get_children()[fog].disable_isolated()
	
	picker.queue_free()
	

## Check if .png files exist in target path
func find_files():
	var dir = DirAccess.open(heightmap_dir)
	var cnt = -1
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.get_extension() == "png":
				cnt+=1
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	return cnt


func update_navigation_meshes(grp):
	var targ = "Region"
	if(grp != null):
		targ += grp.get_slice("g",1)
	for i in get_children():
		if i.name.contains(targ):
			i.update_navigation_mesh()	

#endregion


#region Build map Functions

func build_map(img, pos, adj):	
	var grp = StringName("reg_"+str(adj.x) +"_"+ str(adj.y))
	#build nav region for chunk
	var chunk_nav_region = NavigationRegion3D.new()
	chunk_nav_region.set_script(nav_manager)
	chunk_nav_region.finished_baking.connect(gamescene._navmesh_updated)
	chunk_nav_region.starting_baking.connect(gamescene._navmesh_update_start)
	chunk_nav_region.add_to_group(grp)
	#build mesh for chunk
	var mesh = MeshInstance3D.new()
	mesh.set_mesh(create_mesh(img))
	mesh.set_name("Floor")
	#add to world
	add_child(chunk_nav_region)
	get_child(-1).set_name("Region_"+str(adj.x) +"_"+ str(adj.y))
	chunk_nav_region.add_child(mesh)
	mesh.create_trimesh_collision()
	mesh.add_to_group(grp)
	mesh.add_to_group("water")
	mesh.get_child(0).add_to_group(grp)
	mesh.get_child(0).add_to_group("water")
	
	mesh.position = pos*chunk_size - Vector3(map_offset + adj.x,0,adj.y)
	mesh.position.z -= (map_offset-chunk_size)
	
	var scale_ratio = chunk_size / float(img.get_width())
	mesh.scale *= scale_ratio


func create_mesh(img):
	var st = ImmediateMesh.new()
	st.clear_surfaces()
	var width = img.get_width()
	var height = img.get_height()	
	img.flip_y()
	
	vertices.resize(0)
	UVs.resize(0)
	normals.resize(0)
	
	var _heightmap = img
	
	for x in range(width):
		if x % meshres == 0:
			for y in range(height):
				if y % meshres == 0:
					height_data[Vector2(x,y)] = _heightmap.get_pixel(x,y).r * terrain_amplitude
					if(height_data[Vector2(x,y)] < water_table-.15):
						height_data[Vector2(x,y)] -= (100 + rng.randf_range(10,50))
		
	
	for x in height_data:
		if (x.x<width-meshres and x.y<height-meshres):
			createQuad(x.x,x.y)
	st.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for v in vertices.size():
		st.surface_set_uv(UVs[v])
		st.surface_set_normal(normals[v])
		st.surface_add_vertex(vertices[v])
	st.surface_end()
	return st


func createQuad(x,y):	
	var vert1
	var vert2
	var vert3
	var side1
	var side2
	var normal
	
	vert1 = Vector3(x,height_data[Vector2(x,y)],-y)
	vert2 = Vector3(x,height_data[Vector2(x,y+meshres)], -y-meshres)
	vert3 = Vector3(x+meshres, height_data[Vector2(x+meshres,y+meshres)],-y-meshres)
	vertices.push_back(vert1)
	vertices.push_back(vert2)
	vertices.push_back(vert3)
	
	UVs.push_back(Vector2(vert1.x, -vert1.z))
	UVs.push_back(Vector2(vert2.x, -vert2.z))
	UVs.push_back(Vector2(vert3.x, -vert3.z))
	
	side1 = vert2-vert1
	side2 = vert2-vert3
	normal = side1.cross(side2)
	
	for i in range(0,3):
		normals.push_back(normal)
	
	vert1 = Vector3(x,height_data[Vector2(x,y)],-y)
	vert2 = Vector3(x+meshres, height_data[Vector2(x+meshres,y+meshres)], -y-meshres)
	vert3 = Vector3(x+meshres, height_data[Vector2(x+meshres,y)],-y)
	vertices.push_back(vert1)
	vertices.push_back(vert2)
	vertices.push_back(vert3)
	
	UVs.push_back(Vector2(vert1.x, -vert1.z))
	UVs.push_back(Vector2(vert2.x, -vert2.z))
	UVs.push_back(Vector2(vert3.x, -vert3.z))
	
	side1 = vert2-vert1
	side2 = vert2-vert3
	normal = side1.cross(side2)
	
	for i in range(0,3):
		normals.push_back(normal)

#endregion


#region Ping Location Functions

func get_region(pos : Vector3):
	return StringName("reg_"+str(int(pos.x/chunk_size)) +"_"+ str(int(pos.z/chunk_size)))


func get_loc_height(pos:Vector3):
	var x = pos.x+map_offset
	var y = pos.z+map_offset
	var t = heightmap.get_pixel(x,y).r * terrain_amplitude
	return clamp(t,water_table,1000)

#endregion


#region Building Texture Interactions

## Update tree scatter avoidance texture
func building_added(pos: Vector3, building:Building, bldg_radius: float, road_target: Vector3):
	var circle_size := bldg_radius * 15
	
	var cntr = Vector2(pos.x,pos.z)
	
	##Build road to base
	if road_target != Vector3.ZERO:
		for i in range(circle_size/2.8, cntr.distance_to(Vector2(road_target.x,road_target.z))):
			var p = cntr + (i * cntr.direction_to(Vector2(road_target.x,road_target.z)))
			_draw_circle_to_buildings_tex(14, Vector2(p.x,p.y), 3, .45)
	
	##Make circle around buildings in tex to hide trees
	if building.draw_shape_size == 0:
		_draw_circle_to_buildings_tex(circle_size, Vector2(pos.x,pos.z), building.ground_drawing)
	if building.draw_shape == "Square":
		_draw_square_to_buildings_tex(building.draw_shape_size, Vector2(pos.x,pos.z), building.ground_drawing, building.elevation_drop)
	else:
		_draw_circle_to_buildings_tex(building.draw_shape_size, Vector2(pos.x,pos.z), building.ground_drawing,.125, building.elevation_drop)
		
	## Write to global dsharer parameter
	RenderingServer.global_shader_parameter_set("building_locs",ImageTexture.create_from_image(building_locations))
	
	_update_forests()
	
## Update Forest Avoidance areas
func _update_forests():
	for nod in get_children():
		if nod is forest:
			nod.hide_avoidance_zones_under_buildings(building_locations,map_offset)

## Draw to buildic_locations tex

func _draw_circle_to_buildings_tex(circle_size, pos, channel_bitfield: int ,lighten_offset:float = .125, intensity = 1, max_intensity = 100):
	var pix = Vector2((pos.x+map_offset-(circle_size/2)),(pos.y+map_offset-(circle_size/2)))
	var cntr = Vector2((pos.x+map_offset),(pos.y+map_offset))
	for y in range(circle_size):
		if pix.y+y > building_locations.get_width():
			continue
		for x in range(circle_size):
			if pix.x+x > building_locations.get_width():
				continue
			var b_map = channel_bitfield
			var p =Vector2(pix.x+x,pix.y+y)
			var col = building_locations.get_pixel(p.x,p.y)
			var n_col = Color.BLACK
			## Go through bitmap
			##red
			if (b_map >= 4):
				b_map -= 4
				col.b = clamp(n_col.b,col.b,max_intensity)
			##green
			if (b_map >= 2):	
				b_map -= 2
				n_col.g += 1 - (p.distance_to(cntr)/(circle_size/2)) - lighten_offset
				if (n_col.g < 0.25):
					n_col.g *= randf_range(0.25,1.25)
				col.g = clamp(n_col.g,col.g,max_intensity)
			elif(p.distance_to(cntr) <= circle_size/4):
				col.g = 0
			##blue
			if (b_map >= 1):
				n_col.r += 1-(p.distance_to(cntr)/(circle_size/2)) - lighten_offset
				col.r = clamp(n_col.r,col.r,max_intensity)
			building_locations.set_pixel(p.x,p.y,col)

## Channel bitfield
## 4 - Red
## 2 - Green
## 1 - Blue
func _draw_square_to_buildings_tex(square_size, pos,channel_bitfield = 7, intensity = 1, max_intensity = 100):
	var pix = Vector2((pos.x+map_offset-(square_size/2)),(pos.y+map_offset-(square_size/2)))
	var cntr = Vector2((pos.x+map_offset),(pos.y+map_offset))
	for y in range(square_size):
		if y > building_locations.get_width():
			continue
		for x in range(square_size):
			if x > building_locations.get_width():
				continue
			var b_map = channel_bitfield
			var p =Vector2(pix.x+x,pix.y+y)
			var col = building_locations.get_pixel(p.x,p.y)
			var n_col = Color(intensity,(2-p.distance_to(cntr)/(square_size/2))*intensity,intensity)
			## Go through bitmap
			if (b_map >= 4):
				col.b = clamp(n_col.b,col.b,max_intensity)
				b_map-=4
			if (b_map >= 2):
				b_map-=2
				col.g = clamp(n_col.g,col.g,max_intensity)
			if (b_map >= 1):
				col.r = clamp(n_col.r,col.r,max_intensity)
			building_locations.set_pixel(p.x,p.y,col)

#endregion

## Get base spawn for player
func get_base_spawn(trgt_player : int):
	var bases = find_child("Base_Spawns").get_children()
	if use_random_base_spawns:
		return bases[rng.randi_range(0,bases.size()-1)]
	for i in bases:
		if i.actor_id == trgt_player:
			return i

#region Change Data

func get_ground_tex():
	return $"Visual_Ground".mesh.surface_get_material(0).get_shader_parameter("grass_alb_tex")

func set_ground_tex(new_tex: Texture2D):
	$"Visual_Ground".mesh.surface_get_material(0).set_shader_parameter("grass_alb_tex",new_tex)
	
#endregion

