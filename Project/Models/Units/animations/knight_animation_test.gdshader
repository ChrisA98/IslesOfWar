shader_type spatial;
render_mode blend_mix,depth_draw_always,cull_back,diffuse_burley,specular_schlick_ggx;

global uniform sampler2D heightmap_tex;
global uniform vec2 heightmap_tex_size = vec2(1000.0,1000.0);

uniform sampler2D offset_map;
uniform sampler2D normal_map;
uniform sampler2D texture_albedo;

uniform float time_scale = 4.0;

uniform float specular;
uniform float metallic;
uniform float roughness : hint_range(0,1);
uniform bool use_color_override;

varying float hide;

float get_height(vec2 x){
  float hgt = (texture(heightmap_tex,x).y) * 100.0;
  return hgt;
}

void vertex(){
	
	if (COLOR.a > 0.0){
		hide = 0.0;
		float time_int = 1.0;
		float time = modf(TIME * time_scale, time_int)+(float(INSTANCE_ID)/10.0);
		float num_frames = INSTANCE_CUSTOM.y - INSTANCE_CUSTOM.x;
		float current_frame = INSTANCE_CUSTOM.x + mod((time * num_frames), num_frames);
		float interp_frame = INSTANCE_CUSTOM.z + mod((time * num_frames), num_frames);
		
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
		VERTEX.y += get_height(pos_uv);
		
		vec3 normal_floor = texture(normal_map, UV2 + frame_floor_uv_offset).xyz;
		vec3 normal_ceil = texture(normal_map, UV2 + frame_ceil_uv_offset).xyz;
		vec3 normal_lerp = mix(normal_floor, normal_ceil, lerp_factor);
		vec3 new_normal = vec3((normal_lerp.x * 2.0) - 1.0, (normal_lerp.z * 2.0) - 1.0, (normal_lerp.y * 2.0) - 1.0);
		
		NORMAL = new_normal;
	}else{
		VERTEX = vec3(0,0,0);
		hide = 1.0;
	}
}

void fragment(){
		vec3 albedo_col = texture(texture_albedo, UV).rgb;
		if (use_color_override){
			ALBEDO=COLOR.rgb;
		}else{
			ALBEDO = albedo_col.rgb;
		}
		METALLIC = metallic;
		ROUGHNESS = roughness;
		SPECULAR = specular;
		ALPHA = 1.0;
}