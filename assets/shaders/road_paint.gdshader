shader_type spatial;
render_mode depth_draw_opaque;
uniform vec4 paint_color : source_color = vec4(0.65, 0.62, 0.52, 1.0);
varying vec3 world_pos;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 // Chipped traffic paint; alpha scissor keeps it out of the transparent pass.
 float chip = hash21(floor(world_pos.xz * 65.0));
 float wear = hash21(floor(world_pos.xz * 7.0));
 ALPHA = chip > 0.2 + wear * 0.30 ? 1.0 : 0.0;
 ALPHA_SCISSOR_THRESHOLD = 0.5;
 ALBEDO = paint_color.rgb * (0.82 + chip * 0.18);
 ROUGHNESS = 0.95;
}
