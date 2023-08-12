shader_type canvas_item;

global uniform sampler2D building_locs;

void fragment() {
	vec4 test = texture(building_locs,UV);
	COLOR = test;
}
