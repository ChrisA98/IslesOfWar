shader_type spatial;

uniform sampler2D heightmap : repeat_disable;
uniform float height_ratio = 36;
uniform sampler2D _a;

void fragment() {
	ALBEDO = texture(_a,UV).rgb;
	NORMAL_MAP += texture(heightmap, UV).r * height_ratio;
	NORMAL_MAP_DEPTH += texture(heightmap, UV).r * height_ratio;
}

void light(){
}

void vertex(){
	VERTEX.y += texture(heightmap, UV).r * height_ratio;
}
