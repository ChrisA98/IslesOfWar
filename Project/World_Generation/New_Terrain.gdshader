shader_type spatial;
render_mode diffuse_lambert;

uniform sampler2D heightmap : repeat_enable;
uniform float t_height;
uniform sampler2D Albedo : source_color;
uniform mat3 u_terrain_normal_basis;

void vertex() {
	float height = texture(heightmap,UV).y;
	VERTEX.y += height * t_height;
	
	vec2 e = vec2(0.1,0.0);	
	vec3 normal = normalize(vec3(texture(heightmap,UV-e).y * t_height - texture(heightmap,UV+e).y * t_height, 1.0 * e.x, texture(heightmap,UV - e.yx).y * t_height - texture(heightmap,UV + e.yx).y * t_height));
	COLOR.xyz = vec3(height);
	
}

void fragment() {
	ALBEDO = texture(Albedo,UV).xyz;
}
