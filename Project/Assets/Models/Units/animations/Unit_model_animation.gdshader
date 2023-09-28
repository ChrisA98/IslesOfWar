shader_type spatial;
render_mode blend_mix,depth_draw_always,cull_back,diffuse_burley,specular_schlick_ggx;

global uniform sampler2D heightmap_tex;
global uniform vec2 heightmap_tex_size = vec2(1000.0,1000.0);
global uniform float game_time;
global uniform float water_depth;

uniform sampler2D offset_map;
uniform sampler2D normal_map;
uniform vec3 albedo_color: source_color = vec3(1,1,1);
uniform sampler2D texture_albedo;
uniform sampler2D texture_normal;
uniform float normal_depth;

uniform bool is_naval_unit;
uniform float model_y_rotation_deg;
uniform float vert_offset;

uniform float time_scale = 4.0;

uniform float specular;
uniform float metallic;
uniform float roughness : hint_range(0,1);
uniform bool use_color_override;


vec2 rotate2D(vec2 v, float a) {
	a = a*0.0174533;
    float s = sin(a);
    float c = cos(a);
    mat2 m = mat2(vec2(c,-s),vec2(s,c));
    return m * v;
}


vec3 get_height(vec2 x){
	return vec3(0,texture(heightmap_tex,x.xy).y * 100.0,0);
}


vec3 sea_bob(vec3 x, float rand){
	vec3 offset = x + vec3(0, water_depth + sin(TIME+rand)/4.0,0);
	offset.y += vert_offset;
	offset.xy = rotate2D(offset.xy,sin(TIME+rand)*4.0);
	offset.yz = rotate2D(offset.yz,sin(TIME+5.0+rand)*3.0);
	return offset;	
}


void vertex(){	
	if (COLOR.a > 0.0){
		float time_int = 1.0;
		float time = modf((game_time-INSTANCE_CUSTOM.z) * time_scale, time_int);
		float num_frames = INSTANCE_CUSTOM.y - INSTANCE_CUSTOM.x;
		float frame_offset = num_frames * INSTANCE_CUSTOM.w;
		float current_frame = INSTANCE_CUSTOM.x + mod((time * num_frames)+frame_offset, num_frames);
		
		ivec2 tex_size = textureSize(offset_map, 0);
		float pixel_size = 1.0 / float(tex_size.y);
		
		//base frame floors
		float frame_floor = clamp(floor(current_frame), INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.y);
		float frame_ceil = clamp(ceil(current_frame), INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.y);
		//base floor offsets
		vec2 frame_floor_uv_offset = vec2(0.0, -((frame_floor + 0.5) * pixel_size));
		vec2 frame_ceil_uv_offset = vec2(0.0, -((frame_ceil + 0.5) * pixel_size));
		
		//Base Offset Calc
		float lerp_factor = current_frame - frame_floor;
		
		vec3 offset_floor = texture(offset_map, UV2 + frame_floor_uv_offset).xyz;
		vec3 offset_ceil = texture(offset_map, UV2 + frame_ceil_uv_offset).xyz;
		vec3 offset_lerp = mix(offset_floor, offset_ceil, lerp_factor);
		vec3 new_offset = vec3(offset_lerp.x, offset_lerp.z, offset_lerp.y);
		
		vec3 inst_pos = MODEL_MATRIX[3].xyz;
		vec2 pos_uv = vec2((inst_pos.x)/heightmap_tex_size.x,(inst_pos.z)/heightmap_tex_size.y)+ vec2(.5);
		
		VERTEX += new_offset;
		VERTEX.xz = rotate2D(VERTEX.xz,model_y_rotation_deg);
		if (is_naval_unit){
			VERTEX = sea_bob(VERTEX,INSTANCE_CUSTOM.w);
		}else{
			VERTEX += get_height(pos_uv);
		}
		vec3 normal_floor = texture(normal_map, UV2 + frame_floor_uv_offset).xyz;
		vec3 normal_ceil = texture(normal_map, UV2 + frame_ceil_uv_offset).xyz;
		vec3 normal_lerp = mix(normal_floor, normal_ceil, lerp_factor);
		vec3 new_normal = vec3((normal_lerp.x * 2.0) - 1.0, (normal_lerp.z * 2.0) - 1.0, (normal_lerp.y * 2.0) - 1.0);
		
		NORMAL = new_normal;
	}else{
		VERTEX = vec3(0,0,0);
	}
}


void fragment(){
	vec4 albedo_col = texture(texture_albedo, UV).rgba;
	if (use_color_override){
		ALBEDO= albedo_color * COLOR.rgb;
	}else{
		ALBEDO = albedo_color * albedo_col.rgb;
	}
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	ALPHA = albedo_col.a;
	ALPHA_SCISSOR_THRESHOLD = .5;
	NORMAL_MAP = texture(texture_normal,UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
}