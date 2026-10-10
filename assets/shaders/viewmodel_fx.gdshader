shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
// First-person muzzle flash: same projection as the viewmodel (its own FOV, in front of the world),
// additive. Billboards face the camera; spin is per instance.
global uniform float viewmodel_fov_scale;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform bool billboard = false;
uniform float intensity = 1.0;
instance uniform float spin = 0.0;
void vertex() {
	vec4 view;
	if (billboard) {
		view = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
		float s = length(MODEL_MATRIX[0].xyz);
		vec2 v = VERTEX.xy * s;
		float c = cos(spin), d = sin(spin);
		view.xy += vec2(v.x * c - v.y * d, v.x * d + v.y * c);
	} else {
		view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	}
	mat4 p = PROJECTION_MATRIX;
	p[0][0] *= viewmodel_fov_scale;
	p[1][1] *= viewmodel_fov_scale;
	POSITION = p * view;
	POSITION.z = mix(POSITION.z, POSITION.w, 0.9);
}
void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb * intensity;
	ALPHA = c.a;
}
