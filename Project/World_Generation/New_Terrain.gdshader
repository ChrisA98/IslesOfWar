shader_type spatial;
render_mode diffuse_lambert_wrap;

uniform sampler2D heightmap : repeat_enable;
uniform float t_height;
uniform float universal_tex_scaling = 6;
uniform sampler2D grass_alb_tex : source_color;
uniform sampler2D grass_norm_tex : source_color;
uniform sampler2D cliff_alb_tex : source_color;
uniform sampler2D cliff_norm_tex : source_color;

uniform float min_rock_slope:hint_range(0.0,1.0) = 0.5;
uniform float max_grass_slope:hint_range(0.0,1.0) = 0.9;

varying float normal_y;

float fbm(vec2 x){
  float hgt = (texture(heightmap,x).y) * t_height;
  return hgt;
}

void vertex() {
	float height = fbm(UV);
	VERTEX.y = height;
	
	vec2 e = vec2(0.01, 0.0);
	vec3 normal = normalize(vec3(fbm(UV - e) / t_height - fbm(UV + e) / t_height, 2.0 * e.x, fbm(UV - e.yx) / t_height - fbm(UV + e.yx) / t_height));
	NORMAL = normal;	
	
	normal_y = normal.y;
}

void fragment(){
	//Albedo Values
	vec3 grass_albedo = texture(grass_alb_tex,UV*universal_tex_scaling).xyz;
	vec3 rock_albedo = texture(cliff_alb_tex,UV*universal_tex_scaling).xyz;
	vec3 dirt_albedo = vec3(.35,.3,.1);
	//Normal Values
	vec3 grass_normal = texture(grass_norm_tex,UV*universal_tex_scaling).xyz;
	vec3 rock_normal = texture(cliff_norm_tex,UV*universal_tex_scaling).xyz;
	//Weights
	float rock_grass_weight = normal_y;
	//Calculating Rock/Grass Weight
	rock_grass_weight = max(min_rock_slope+.1, rock_grass_weight);
	rock_grass_weight = min(max_grass_slope-.1, rock_grass_weight);
	rock_grass_weight -= min_rock_slope;
	rock_grass_weight /= max_grass_slope - min_rock_slope;
	//Mixing and Assigning Albedo
	vec3 alb_basic = mix(rock_albedo, dirt_albedo, rock_grass_weight);	
	rock_grass_weight = normal_y;
	//Calculating Rock/Grass Weight
	rock_grass_weight = max(min_rock_slope, rock_grass_weight);
	rock_grass_weight = min(max_grass_slope, rock_grass_weight);
	rock_grass_weight -= min_rock_slope;
	rock_grass_weight /= max_grass_slope - min_rock_slope;
	//Mixing and Assigning Albedo
	alb_basic = mix(alb_basic, grass_albedo, rock_grass_weight);
	ALBEDO = alb_basic;
	SPECULAR = 0.02;
	ROUGHNESS = .5;
	NORMAL = mix(rock_normal, grass_normal, rock_grass_weight);
	NORMAL_MAP = mix(rock_normal, grass_normal, rock_grass_weight);
}