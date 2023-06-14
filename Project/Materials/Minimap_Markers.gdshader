shader_type canvas_item;

uniform int space = 100;

//markers
uniform sampler2D friendly_markers;
uniform sampler2D enemy_markers;

void fragment() {	
	// Draw firendly Icons
	COLOR = texture(friendly_markers,UV);
	
	// Erase friendly Bases
	if(COLOR.rgb == vec3(0.0,0.0,0.0)){
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
	
	// Erase enemy bases and draw to map
	vec4 e_markers = texture(enemy_markers,UV);
	if(e_markers.rgb == vec3(0.0,0.0,0.0)){
		e_markers = vec4(0.0,0.0,0.0,0.0);
	}
	
	// Draw Border to Markers
	vec4 fow = texture(friendly_markers,UV);
	if(fow.a > 0.1){
		vec2 pixel_size = 1.0 / vec2(textureSize(friendly_markers, 0));
		for(int y = -1*space; y <= space; y+=space*2)
		for(int x = -1*space; x <= space; x+=space*2)
		{
			vec2 pixel_off = vec2(float(x), float(y));
			vec4 tex = texture(friendly_markers, UV + pixel_off * pixel_size);
			if(tex != COLOR)
			{
				COLOR = vec4(0.0, 0.0, 0.0, 0.0);
			}
			vec4 e_tex = texture(enemy_markers, UV + pixel_off * pixel_size);
			if(e_tex == e_markers)
			{
				COLOR += e_markers;
				break;
			}
		}
	}
	else{
		COLOR = vec4(0.0, 0.0, 0.0, 0.5);
	}
	
}
