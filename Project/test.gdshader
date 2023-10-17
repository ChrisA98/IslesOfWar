shader_type canvas_item;

global uniform sampler2D heightmap_tex : repeat_disable;
global uniform float game_time;
uniform float progress;

void fragment() {
	COLOR = texture(heightmap_tex,UV);
}
