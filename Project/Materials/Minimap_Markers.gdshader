shader_type canvas_item;

uniform int space = 100;

uniform vec4 clear = vec4(0,0,0,0);
//markers
uniform sampler2D friendly_markers;
uniform sampler2D enemy_markers;



void fragment() {
	COLOR = texture(friendly_markers,UV);
	vec2 pixel_size = 1.0 / vec2(textureSize(friendly_markers, 0));
	for(int y = -1*space; y <= space; y+=space*2)
	for(int x = -1*space; x <= space; x+=space*2)
	{
		vec2 pixel_off = vec2(float(x), float(y));
		vec4 tex = texture(friendly_markers, UV + pixel_off * pixel_size);
		if(tex == vec4(0.0, 0.0, 0.0, 0.0))
		{
			COLOR = vec4(0.0, 0.0, 0.0, 0.0);
			break;
		}
	}
	if(texture(friendly_markers,UV).a > 0.1){
		COLOR += texture(enemy_markers,UV);
	}
	COLOR += texture(enemy_markers,UV);
	
}
