shader_type canvas_item;

global uniform sampler2D heightmap_tex : repeat_disable;
global uniform sampler2D ground_tex_main : repeat_disable;
global uniform float game_time;
uniform float progress;

void fragment() {
	COLOR = texture(ground_tex_main,UV);
}
