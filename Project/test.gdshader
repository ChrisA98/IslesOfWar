shader_type canvas_item;

void fragment() {
	float t = mod(TIME,1);
	COLOR = vec4(t,-t,-t,1);
}
