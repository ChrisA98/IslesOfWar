shader_type spatial;
render_mode unshaded;


uniform sampler2D cloud_tex : source_color;
uniform float time_scale = 1.0;
uniform float dark_scale = 1.0;

varying float time_1;
varying float time_2;

void vertex() {
	
	time_1 = (TIME) * time_scale;
	time_2 = (TIME) * time_scale * 0.1;
}

void fragment() {
	ALBEDO = texture(cloud_tex,vec2(UV.x-time_1,UV.y)).rgb;
	ALPHA = ALBEDO.r*0.85;
	if (ALBEDO.r <=dark_scale){
		ALPHA=0.0;
	}
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
