shader_type spatial;

uniform vec2 tex_size = vec2(1000.0,1000.0);
uniform float fog_darkness:hint_range(0,1) = 1;
//current fog
uniform sampler2D fog;

varying vec2 pos_uv;

void vertex(){
	pos_uv = vec2((NODE_POSITION_WORLD.x)/tex_size.x,(NODE_POSITION_WORLD.z)/tex_size.y)+((vec2(VERTEX.x,VERTEX.z)/tex_size)) + vec2(.5);	
}

void fragment() {
	ALBEDO = vec3(0,0,0);
	ALPHA = 0.0;
	vec4 fog_color = texture(fog, pos_uv);
	if(fog_color.a < 0.1){
		ALPHA = 1.0-fog_darkness;
	}
}
