shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, unshaded;

uniform float health_amount : hint_range(0.0,0.99) = 0;
uniform vec3 health_bar_color: source_color;

vec3 bboard(mat4 mv_m, vec3 vert){	
    // Identity Matrix - simple bilboard
    // #################################
	float z = radians(-90);
	
    mat4 identity = mv_m;

    identity[0][0] = 1.0;
    identity[0][1] = 0.0;
    identity[0][2] = 0.0;

    identity[1][0] = 0.0;
    identity[1][1] = 1.0;
    identity[1][2] = 0.0;

    identity[2][0] = 0.0;
    identity[2][1] = 0.0;
    identity[2][2] = 1.0;
	

    mat4 rotate_z = mat4(0.0);

    rotate_z[0][0] = cos(z);
    rotate_z[0][1] = sin(z);
    rotate_z[0][2] = 0.0;

    rotate_z[1][0] = -sin(z);
    rotate_z[1][1] = cos(z);
    rotate_z[1][2] = 0.0;

    rotate_z[2][0] = 0.0;
    rotate_z[2][1] = 0.0;
    rotate_z[2][2] = 1.0;

    rotate_z[3][3] = 1.0;
	
	return (identity * rotate_z * vec4(vert, 1.0)).xyz;
}

void vertex(){
    VERTEX = bboard(MODELVIEW_MATRIX,VERTEX);
}

void fragment(){
	float h_ratio = health_amount/1.0;
	
	ALBEDO = health_bar_color;
	
	if (1.0-UV.y > h_ratio){
		ALPHA = 0.0;
	}
}
