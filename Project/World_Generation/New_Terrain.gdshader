shader_type spatial;
render_mode diffuse_lambert_wrap;

global uniform sampler2D heightmap_tex : repeat_disable;
global uniform sampler2D building_locs;

uniform float t_height;
uniform float water_table:hint_range(-50.0,50.0) = 1;
uniform float max_sand_height:hint_range(-50.0,50.0) = 1;
uniform float universal_tex_scaling = 6;
uniform sampler2D grass_alb_tex : source_color;
uniform sampler2D grass_norm_tex : source_color;
uniform sampler2D cliff_alb_tex : source_color;
uniform sampler2D cliff_norm_tex : source_color;
uniform sampler2D sand_alb_tex : source_color;
uniform sampler2D sand_norm_tex : source_color;

uniform float min_rock_slope:hint_range(0.0,1.0) = 0.5;
uniform float max_grass_slope:hint_range(0.0,1.0) = 0.9;

//current fog
global uniform sampler2D fog_tex;
//mesh displacement
global uniform vec2 heightmap_tex_size = vec2(1000.0,1000.0);
global uniform float fog_darkness;

varying vec3 normal;
varying float height;
varying vec2 pos_uv;

float get_height(vec2 x){
  float hgt = (texture(heightmap_tex,x).y) * t_height;
  return hgt;
}


void vertex() {
	pos_uv = vec2((NODE_POSITION_WORLD.x)/heightmap_tex_size.x,(NODE_POSITION_WORLD.z)/heightmap_tex_size.y)+((vec2(VERTEX.x,VERTEX.z)/heightmap_tex_size)) + vec2(.5);
	height = get_height(pos_uv);
	VERTEX.y = height - NODE_POSITION_WORLD.y;
		
	vec2 e = vec2(0.01, 0.0);
	normal = normalize(vec3(get_height(pos_uv - e) / t_height - get_height(pos_uv + e) / t_height, 2.0 * e.x, get_height(pos_uv - e.yx) / t_height - get_height(pos_uv + e.yx) / t_height));
	NORMAL = normal;
}

void fragment(){
	//Albedo Values
	vec3 grass_albedo = texture(grass_alb_tex,pos_uv*universal_tex_scaling).xyz;
	vec3 rock_albedo = texture(cliff_alb_tex,pos_uv*universal_tex_scaling).xyz;
	vec3 sand_albedo = texture(sand_alb_tex,pos_uv*universal_tex_scaling).xyz;
	vec3 dirt_albedo = vec3(.35,.3,.1);
	//Normal Values
	vec3 grass_normal = texture(grass_norm_tex,pos_uv*universal_tex_scaling).xyz;
	grass_normal = normalize(grass_normal * 2.0 - 1.0);
	vec3 rock_normal = texture(cliff_norm_tex,pos_uv*universal_tex_scaling).xyz;
	rock_normal = normalize(rock_normal * 2.0 - 1.0);
	vec3 sand_normal = texture(sand_norm_tex,pos_uv*universal_tex_scaling).xyz;
	sand_normal = normalize(sand_normal * 2.0 - 1.0);
	//Weights
	float rock_grass_weight = normal.y;
	//Calculating Rock/Grass Weight
	rock_grass_weight = max(min_rock_slope-.1, rock_grass_weight);
	rock_grass_weight = min(max_grass_slope-.1, rock_grass_weight);
	rock_grass_weight -= min_rock_slope;
	rock_grass_weight /= max_grass_slope - min_rock_slope;
	//Mixing and Assigning Albedo
	vec3 alb_basic = mix(rock_albedo, dirt_albedo, rock_grass_weight);	
	rock_grass_weight = normal.y;
	//Calculating Rock/Grass Weight
	rock_grass_weight = max(min_rock_slope, rock_grass_weight);
	rock_grass_weight = min(max_grass_slope, rock_grass_weight);
	rock_grass_weight -= min_rock_slope;
	rock_grass_weight /= max_grass_slope - min_rock_slope;
	//Mixing and Assigning Albedo
	alb_basic = mix(alb_basic, grass_albedo, rock_grass_weight);
	float sand_rockgrass_weight = height;
	//Calculating Sand/RockGrass Weight
	sand_rockgrass_weight = max(water_table, sand_rockgrass_weight);
	sand_rockgrass_weight = min(max_sand_height, sand_rockgrass_weight);
	sand_rockgrass_weight -= water_table;
	sand_rockgrass_weight /= max_sand_height - water_table;
	//Mixing and Assigning Albedo
	vec3 rockgrass_albedo = mix(rock_albedo, grass_albedo, rock_grass_weight);
	ALBEDO = mix(sand_albedo, rockgrass_albedo, sand_rockgrass_weight);
	SPECULAR = 0.02;
	ROUGHNESS = .5;
	NORMAL_MAP_DEPTH = normal.y*.1;
	NORMAL_MAP = mix(rock_normal, grass_normal, rock_grass_weight);
	
	vec4 buildings = texture(building_locs, pos_uv);
	
	ALBEDO = mix(sand_albedo, ALBEDO, 1.0-buildings.g);
	
	vec4 fog_color = texture(fog_tex, pos_uv);
	if(fog_color.a < 0.1){
		ALBEDO = mix(ALBEDO, vec3 (0,0,0), fog_darkness);
	}
}