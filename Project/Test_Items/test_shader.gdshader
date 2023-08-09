shader_type canvas_item;

global uniform sampler2D building_locs;

void fragment() {
	vec4 test = vec4(texture(building_locs,UV).r,0.0,0.0,1.0);
	if(test.r >= 0.5){		
		COLOR = test;
	}
}
