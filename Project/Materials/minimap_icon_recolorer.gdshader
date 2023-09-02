shader_type canvas_item;

uniform vec4 icon_color : source_color;

void fragment() {
	COLOR.rgb = icon_color.rgb;
}
