shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Preserve the CC0 plaster's chips/normal detail, without its baked orange hue.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_tex : hint_default_white, filter_linear_mipmap;
uniform vec4 district_color : source_color = vec4(0.72, 0.69, 0.61, 1.0);
uniform float normal_scale = 1.0;
uniform float roughness_scale = 1.0;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec3 source = texture(albedo_tex, UV).rgb;
 float value = dot(source, vec3(0.2126, 0.7152, 0.0722));
 // UV streaks remain aligned with the facade modules; world-space damp varies
 // along the whole building rather than resetting on every three metre panel.
 float streak = sin(UV.x * 93.0 + sin(UV.x * 31.0)) * sin(UV.x * 187.0);
 float damp = (1.0 - smoothstep(0.15, 2.1, world_pos.y)) * 0.28;
 float aging = 1.0 - damp - max(streak, 0.0) * 0.055;
 ALBEDO = mix(vec3(value), source, 0.10) * district_color.rgb * aging;
 NORMAL_MAP = texture(normal_tex, UV).rgb;
 NORMAL_MAP_DEPTH = normal_scale;
 ROUGHNESS = clamp(texture(roughness_tex, UV).g * roughness_scale + damp * 0.15, 0.65, 1.0);
}
