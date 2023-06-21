shader_type spatial;

uniform sampler2D heightmap : repeat_disable;
uniform float t_height;
uniform float water_level;
uniform float tide:hint_range(1.0,7.0) = .25;
uniform float water_turbulence:hint_range(1.0,7.0) = .25;

uniform sampler2D water_alb_tex : source_color;
uniform vec3 water_alb : source_color;
uniform sampler2D water_disp_tex_1 : source_color;
uniform sampler2D water_disp_tex_2 : source_color;
uniform vec2 wave_direction_1 = vec2(2.0,-2);
uniform vec2 wave_direction_2 = vec2(-2.0,2);
uniform float time_scale : hint_range(0.0,0.2) = 0.025;

varying float height;
uniform vec2 tex_size = vec2(1000.0,1000.0);
uniform vec2 wtr_tex_size = vec2(512.0,512.0);
varying vec2 pos_uv;
varying vec2 wtr_pos_uv;

varying vec3 norm1;
varying vec3 norm2;

varying vec2 time_1;
varying vec2 time_2;

float fresnel(float amt, vec3 normal, vec3 view){
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0)), amt);
}

vec4 water_depth_gradient(float position) {
    return texture(water_alb_tex, vec2(position, 0.5));
}

float get_height(vec2 x){
  float hgt = (texture(heightmap,x).y) * t_height;
  return hgt;
}

void vertex() {
	pos_uv = vec2((NODE_POSITION_WORLD.x)/tex_size.x,(NODE_POSITION_WORLD.z)/tex_size.y)+((vec2(VERTEX.x,VERTEX.z)/tex_size)) + vec2(.5);
	wtr_pos_uv = vec2((NODE_POSITION_WORLD.x)/wtr_tex_size.x,(NODE_POSITION_WORLD.z)/wtr_tex_size.y)+((vec2(VERTEX.x,VERTEX.z)/wtr_tex_size)) + vec2(.5);
	height = get_height(pos_uv);
	float depth = clamp((water_level-height)/tide,0.001,0.99);
	
	time_1 = (TIME * wave_direction_1) * time_scale;
	time_2 = (TIME * wave_direction_2) * time_scale;
	
	norm1 = texture(water_disp_tex_1,wtr_pos_uv + time_1).rgb;
	norm2 = texture(water_disp_tex_2,wtr_pos_uv + time_2).rgb;
	vec3 normal_blend = mix(mix(norm1,norm2,0.5),vec3(0,0,0),1.2-depth);
	
	VERTEX.y = water_level - NODE_POSITION_WORLD.y;
}

void fragment() {
	
	float _tide =  tide + norm1.r;
	float depth = clamp((water_level-height)/_tide,0,1);
	vec3 normal_blend = mix(mix(norm1,norm2,0.5),vec3(0,0,0),1.0-depth);
	
	vec3 albedo1 = normalize(water_depth_gradient(depth/1.2)).xyz;
	if(abs(water_level-height) < 0.5){
		albedo1 = mix(vec3(1,1,1),albedo1,abs(water_level-height)*1.6);
	}	
	float fresnel = fresnel(5.0, NORMAL,VIEW);
	vec3 surface_color = mix(albedo1, water_alb, fresnel);
	
	if(height >= water_level-.005){
		ALPHA = 0.0;
	}else{
		ALPHA = clamp(depth*2.3,0.3,1.0);
		ALBEDO = surface_color;
		NORMAL_MAP = normal_blend;
		METALLIC = 0.2;
		ROUGHNESS = 0.02;
		SPECULAR = .75;
	}
}
