// NOTE: Shader automatically converted from Godot Engine 4.1.1.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx,unshaded,world_vertex_coords;
uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_emission : source_color, hint_default_black,filter_linear_mipmap,repeat_enable;
uniform vec4 emission : source_color;
uniform float emission_energy;


global uniform sampler2D heightmap_tex : repeat_disable;
global uniform vec2 heightmap_tex_size = vec2(1000.0,1000.0);
global uniform float water_depth;



float get_height(vec2 x){
  float hgt = (texture(heightmap_tex,x).y) * 100.0;
  return hgt + 0.25;
}

void vertex() {
	vec2 pos_uv = vec2((VERTEX.x)/heightmap_tex_size.x,(VERTEX.z)/heightmap_tex_size.y)+ vec2(.5);
	
	VERTEX.y = 0.0;	
	VERTEX.y = clamp(get_height(pos_uv),water_depth+.25,999);
}

void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(texture_albedo,base_uv);
	ALBEDO = albedo.rgb * albedo_tex.a;
	vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);
	vec3 emission_tex = texture(texture_emission,base_uv).rgb;
	EMISSION = (emission.rgb+emission_tex)*emission_energy;
	ALPHA *= albedo_tex.a;
}
