shader_type spatial;
render_mode diffuse_lambert;

uniform sampler2D heightmap : repeat_enable;
uniform float t_height;
uniform sampler2D Albedo : source_color;
uniform mat3 u_terrain_normal_basis;

void vertex() {
	float height = texture(heightmap,UV).y;
	VERTEX.y += height * t_height;
	
	vec3 ddxp = dFdx(VERTEX);
	vec3 ddyp = dFdy(VERTEX);
	vec3 cr = cross(ddxp,ddyp);
	NORMAL = normalize(cr);
	
}

void fragment() {
	ALBEDO = texture(Albedo,UV).xyz;
}
