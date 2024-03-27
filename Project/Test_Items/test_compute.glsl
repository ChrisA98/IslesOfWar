#[compute]
#version 450

// Instruct the GPU to use 8x8x1 = 64 local invocations per workgroup.
layout(local_size_x = 16, local_size_y = 8, local_size_z = 8) in;

// Invocations in the (x, y, z) dimension
layout(rgba8, binding = 0) restrict uniform image2D alpha_brush;

// `readonly` is used to tell the compiler that we will not write to this memory.
// This allows the compiler to make some optimizations it couldn't otherwise.
layout(rgba8, binding = 1) restrict  uniform image2D texture;


// The code we want to execute in each invocation
void main() {
	// Grab the current pixel's position from the ID of this specific invocation ("thread").
	ivec2 coords = ivec2(gl_GlobalInvocationID.xy);

	vec4 brush_tex = imageLoad(alpha_brush, coords);

	vec4 pixel_tex = imageLoad(texture, coords);

    pixel_tex.w = brush_tex.w;

    imageStore(texture, coords, pixel_tex);
}