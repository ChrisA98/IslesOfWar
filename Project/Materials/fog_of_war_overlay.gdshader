shader_type spatial;


global uniform sampler2D fog_tex;
global uniform vec2 heightmap_tex_size = vec2(1000.0,1000.0);
global uniform float fog_darkness;
varying vec2 pos_uv;


void vertex(){
	pos_uv = vec2((NODE_POSITION_WORLD.x)/heightmap_tex_size.x,(NODE_POSITION_WORLD.z)/heightmap_tex_size.y)+((vec2(VERTEX.x,VERTEX.z)/heightmap_tex_size)) + vec2(.5);
}

void fragment() {
	ALBEDO = vec3(0,0,0);
	ALPHA = 0.0;
	vec4 fog_color = texture(fog_tex, pos_uv);
	if(fog_color.a < 0.1){
		ALPHA = 1.0-fog_darkness;
	}
}
