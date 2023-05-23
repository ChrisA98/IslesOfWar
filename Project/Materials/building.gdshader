shader_type spatial;
render_mode diffuse_lambert_wrap;

uniform float progress = 0;
uniform vec4 magic_color: source_color;
uniform float min_val = -0.2;
uniform float max_val = 1.0;

varying vec3 local_vert;

void vertex(){
	local_vert = VERTEX;
}

void fragment() {
	float loc_prog = ((max_val-min_val)*progress)+min_val;
	if(local_vert.y > loc_prog){
		ALPHA = 0.0;
	}
	ALBEDO = magic_color.rgb;
}
