shader_type spatial;

uniform sampler2D heightmap : repeat_disable;
uniform float t_height;	//terrain amplitude

uniform vec3 target;	//taret direction of unit


float get_height(vec2 x){
  float hgt = (texture(heightmap,x).y) * t_height;
  return hgt;
}

mat3 get_rot_mat(){	
	float deg = atan(target.x, target.z);
	float cosa = cos(deg);
	float sina = sin(deg);
	return mat3(
		vec3(cosa,0,sina),
		vec3(0,1,0),
		vec3(-sina,0,cosa)
	);
}

void vertex() {
	mat3 rotation_matrix = get_rot_mat();
	vec3 rot_vert = rotation_matrix * VERTEX;
	vec3 rotated_normals =  rotation_matrix * NORMAL;
	
	VERTEX = rot_vert;
	NORMAL = rotated_normals;
}

void fragment(){
	
}
