shader_type canvas_item;

global uniform float game_time;

void fragment() {
	float t = mod(game_time,1);
	COLOR = vec4(t,-t,-t,1);
}
