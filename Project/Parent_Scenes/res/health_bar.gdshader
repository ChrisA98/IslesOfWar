shader_type spatial;
render_mode skip_vertex_transform, cull_disabled;

void vertex(){
    // Identity Matrix - simple bilboard
    // #################################

    mat4 identity = MODELVIEW_MATRIX;

    identity[0][0] = 1.0;
    identity[0][1] = 0.0;
    identity[0][2] = 0.0;

    identity[1][0] = 0.0;
    identity[1][1] = 1.0;
    identity[1][2] = 0.0;

    identity[2][0] = 0.0;
    identity[2][1] = 0.0;
    identity[2][2] = 1.0;

    VERTEX = (identity * vec4(VERTEX, 1.0)).xyz;
}
