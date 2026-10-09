shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// World-space triplanar PBR surface for authored architecture.
// Whiteout normal blending (Golus), large-scale tonal variation and a ground
// grime band so tiled ambientCG materials read as weathered built surfaces.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D variation_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tile_size = 2.0;          // metres per texture repeat
uniform float normal_strength = 1.0;
uniform float roughness_scale = 1.0;
uniform float metallic_scale = 1.0;
uniform float variation_strength = 0.18;
uniform float grime_height = 0.7;       // metres of darkened base above floor_level
uniform float grime_strength = 0.35;
uniform float floor_level = 0.0;
uniform float top_projection_only = 0.0; // 1 = floors: sample only the Y plane

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = world_pos / tile_size;
	vec3 n = normalize(world_nrm);
	vec3 w = pow(abs(n), vec3(6.0));
	w = mix(w, vec3(0.0, 1.0, 0.0), top_projection_only);
	w /= max(dot(w, vec3(1.0)), 1e-4);
	float fx = n.x < 0.0 ? -1.0 : 1.0; float fy = n.y < 0.0 ? -1.0 : 1.0; float fz = n.z < 0.0 ? -1.0 : 1.0;
	vec2 ux = vec2(p.z * fx, p.y);
	vec2 uy = vec2(p.x, p.z * fy);
	vec2 uz = vec2(-p.x * fz, p.y);
	vec3 alb = vec3(0.0); vec3 orm = vec3(0.0);
	vec3 tnx = vec3(0.0, 0.0, 1.0); vec3 tny = tnx; vec3 tnz = tnx;
	if (w.x > 0.01) { alb += texture(albedo_tex, ux).rgb * w.x; orm += texture(orm_tex, ux).rgb * w.x; tnx = texture(normal_tex, ux).rgb * 2.0 - 1.0; }
	if (w.y > 0.01) { alb += texture(albedo_tex, uy).rgb * w.y; orm += texture(orm_tex, uy).rgb * w.y; tny = texture(normal_tex, uy).rgb * 2.0 - 1.0; }
	if (w.z > 0.01) { alb += texture(albedo_tex, uz).rgb * w.z; orm += texture(orm_tex, uz).rgb * w.z; tnz = texture(normal_tex, uz).rgb * 2.0 - 1.0; }
	tnx.xy *= normal_strength; tny.xy *= normal_strength; tnz.xy *= normal_strength;
	// Explicit per-plane tangent frames matching the UV choices above.
	float sx = n.x < 0.0 ? -1.0 : 1.0; float sy = n.y < 0.0 ? -1.0 : 1.0; float sz = n.z < 0.0 ? -1.0 : 1.0;
	vec3 nx = vec3(sx * abs(tnx.z), tnx.y, sx * tnx.x);
	vec3 ny = vec3(tny.x, sy * abs(tny.z), sy * tny.y);
	vec3 nz = vec3(-sz * tnz.x, tnz.y, sz * abs(tnz.z));
	vec3 nw = normalize(nx * w.x + ny * w.y + nz * w.z);
	// Low-frequency weathering: tone and roughness drift across the wall.
	float v1 = texture(variation_tex, world_pos.xz * 0.031 + world_pos.y * 0.017).r;
	float v2 = texture(variation_tex, vec2(world_pos.x + world_pos.z, world_pos.y) * 0.083).g;
	float vary = (v1 * 0.65 + v2 * 0.35) - 0.5;
	alb *= 1.0 + vary * variation_strength * 2.0;
	alb = mix(alb, alb * vec3(1.03, 0.99, 0.94), clamp(vary, 0.0, 1.0));
	float above = world_pos.y - floor_level;
	float grime = (1.0 - smoothstep(0.0, grime_height, above)) * grime_strength * (1.0 - w.y * 0.7);
	grime *= 0.75 + v2 * 0.5;
	alb = mix(alb, alb * vec3(0.46, 0.43, 0.38), grime);
	ALBEDO = alb * tint.rgb;
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.25;
	ROUGHNESS = clamp(orm.g * roughness_scale + grime * 0.15 + vary * 0.1, 0.04, 1.0);
	METALLIC = orm.b * metallic_scale;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
