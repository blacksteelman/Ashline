shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_schlick_ggx;
// Transparent first-person surfaces (optic glass). First-person weapons and arms: own field of view and depth packed in front of
// the world (no clipping, no wide-FOV stretching); full PBR with scene lighting.
global uniform float viewmodel_fov_scale;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, hint_default_white;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform float normal_strength = 1.0;
uniform bool use_normal = false;
uniform sampler2D roughness_tex : hint_default_white, filter_linear_mipmap;
uniform vec4 roughness_channel = vec4(0.0, 1.0, 0.0, 0.0);
uniform float roughness = 1.0;
uniform float roughness_floor = 0.0;
uniform float roughness_bias = 0.0;
uniform float specular = 0.5;
uniform sampler2D metallic_tex : hint_default_white, filter_linear_mipmap;
uniform vec4 metallic_channel = vec4(0.0, 0.0, 1.0, 0.0);
uniform float metallic = 0.0;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap;
uniform vec4 ao_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform bool use_ao = false;
uniform float alpha_scissor = 0.0;
// Texels below this alpha are glass: their opacity is scaled down so the lens reads as clear.
uniform float glass_below = 0.98;
uniform float glass_scale = 0.12;
uniform sampler2D emission_tex : source_color, hint_default_black, filter_linear_mipmap;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;

void vertex() {
	mat4 p = PROJECTION_MATRIX;
	p[0][0] *= viewmodel_fov_scale;
	p[1][1] *= viewmodel_fov_scale;
	POSITION = p * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	POSITION.z = mix(POSITION.z, POSITION.w, 0.88);
}

void fragment() {
	vec4 a = texture(albedo_tex, UV) * albedo_color;
	ALBEDO = a.rgb;
	float alpha = a.a < glass_below ? a.a * glass_scale : a.a;
	ALPHA = alpha;
	float r = dot(texture(roughness_tex, UV), roughness_channel) * roughness;
	ROUGHNESS = clamp(mix(r, 1.0, roughness_bias), roughness_floor, 1.0);
	SPECULAR = specular;
	METALLIC = dot(texture(metallic_tex, UV), metallic_channel) * metallic;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	if (use_ao) { AO = dot(texture(ao_tex, UV), ao_channel); AO_LIGHT_AFFECT = 0.4; }
	EMISSION = texture(emission_tex, UV).rgb * emission_color.rgb * emission_energy;
}
