shader_type spatial;

render_mode cull_disabled;

uniform float height_scaling;
uniform float sway_intensity: hint_range(0,0.2);
uniform vec3 albedo : source_color;

float random(vec2 st){
	return fract(sin(dot(st.xy,
	vec2(12.9898,78.233))) * 43758.5453123);
}

void vertex() {
	if(VERTEX.y > 0.0){
		VERTEX.y += VERTEX.y*clamp(random(VERTEX.xz),0.25,1.25)*height_scaling;
		float wave = sin(2.0 * PI * TIME + (VERTEX.z+VERTEX.x)*0.8)*VERTEX.y;
		float wave2 = sin(2.0 * PI * (TIME + VERTEX.z+VERTEX.x)*2.0)*VERTEX.y;
		VERTEX.x += (wave+wave2 *0.4) *sway_intensity;
		VERTEX.z -= (wave-wave2 *0.4)*sway_intensity;
	}
}

void fragment() {
	ALBEDO = albedo;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
