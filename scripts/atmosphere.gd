class_name Atmosphere
extends RefCounted
# Physically based outdoor lighting: CC0 Poly Haven HDRI sky, sun aligned to the
# HDRI's sun, filmic ACES response and per-preset screen-space / global illumination.
const SKY_PATH='res://assets/sky/kloofendal_38d_partly_cloudy_puresky.hdr'
# Sun position measured in the HDRI: elevation 38 deg, equirect azimuth 216 deg.
const SUN_ELEVATION=38.0
const SUN_AZIMUTH=-126.0

static func build(game: Node3D) -> Environment:
 var holder=WorldEnvironment.new();var e=Environment.new();holder.environment=e;game.add_child(holder)
 e.background_mode=Environment.BG_SKY
 var sky=Sky.new();var panorama=PanoramaSkyMaterial.new()
 panorama.panorama=load(SKY_PATH);panorama.energy_multiplier=1.0
 sky.sky_material=panorama;sky.radiance_size=Sky.RADIANCE_SIZE_256;e.sky=sky
 e.background_energy_multiplier=1.0
 e.ambient_light_source=Environment.AMBIENT_SOURCE_SKY;e.ambient_light_sky_contribution=1.0;e.ambient_light_energy=.8
 e.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
 # ACES: the punchier, higher-contrast filmic curve of 2007-2011 shooters (AgX read flat and milky).
 e.tonemap_mode=Environment.TONE_MAPPER_ACES;e.tonemap_exposure=.95;e.tonemap_white=6.0
 # Slightly desaturated, cool shadows and warm highlights: the 2007-2011 military grade.
 e.adjustment_enabled=true;e.adjustment_brightness=1.0;e.adjustment_contrast=1.06;e.adjustment_saturation=.94
 e.glow_enabled=true;e.glow_intensity=.55;e.glow_strength=.9;e.glow_bloom=.04;e.glow_hdr_threshold=1.6;e.glow_blend_mode=Environment.GLOW_BLEND_MODE_SOFTLIGHT
 e.set_glow_level(0,0.0);e.set_glow_level(1,1.0);e.set_glow_level(2,.6);e.set_glow_level(3,.35);e.set_glow_level(4,.15)
 # Distance haze ties the skyline into the sky colour.
 e.fog_enabled=true;e.fog_light_color=Color('#b9b6a8');e.fog_light_energy=.8;e.fog_density=.0005;e.fog_sky_affect=.05;e.fog_aerial_perspective=.25;e.fog_sun_scatter=.25
 e.fog_height=-2.0;e.fog_height_density=.0
 e.ssao_radius=1.1;e.ssao_intensity=1.9;e.ssao_power=1.3;e.ssao_detail=.6;e.ssao_light_affect=.15;e.ssao_ao_channel_affect=.35
 e.ssil_radius=4.0;e.ssil_intensity=.8
 e.ssr_max_steps=48;e.ssr_fade_in=.15;e.ssr_fade_out=2.0;e.ssr_depth_tolerance=.25
 e.sdfgi_use_occlusion=true;e.sdfgi_cascades=4;e.sdfgi_min_cell_size=.2;e.sdfgi_energy=1.25;e.sdfgi_bounce_feedback=.6;e.sdfgi_read_sky_light=true
 e.volumetric_fog_density=.0018;e.volumetric_fog_albedo=Color('#d9dcd6');e.volumetric_fog_anisotropy=.55;e.volumetric_fog_length=48;e.volumetric_fog_detail_spread=2.0;e.volumetric_fog_gi_inject=.4;e.volumetric_fog_sky_affect=.0;e.volumetric_fog_ambient_inject=.15
 var sun=DirectionalLight3D.new();sun.name='Sun';game.add_child(sun)
 sun.rotation_degrees=Vector3(-SUN_ELEVATION,SUN_AZIMUTH,0)
 sun.light_color=Color('#ffe6c4');sun.light_energy=2.2;sun.light_angular_distance=.6
 sun.shadow_enabled=true;sun.shadow_bias=.03;sun.shadow_normal_bias=.9;sun.shadow_blur=1.2
 sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS;sun.directional_shadow_max_distance=110
 sun.directional_shadow_split_1=.06;sun.directional_shadow_split_2=.18;sun.directional_shadow_split_3=.45;sun.directional_shadow_blend_splits=true
 sun.light_volumetric_fog_energy=1.4
 game.set_meta('sun',sun)
 return e

# 0 performance, 1 balanced, 2 quality, 3 ultra.
static func apply(game: Node3D, e: Environment, preset: int):
 var modern=RenderingServer.get_current_rendering_method()=='forward_plus'
 e.ssao_enabled=modern and preset>=1
 e.ssil_enabled=modern and preset>=2
 e.ssr_enabled=modern and preset>=2
 e.sdfgi_enabled=modern and preset>=2
 e.volumetric_fog_enabled=modern and preset>=2
 e.glow_enabled=preset>=1 or not modern
 e.sky.radiance_size=Sky.RADIANCE_SIZE_128 if preset==0 else Sky.RADIANCE_SIZE_256
 var vp=game.get_viewport()
 vp.msaa_3d=Viewport.MSAA_DISABLED if preset==0 else (Viewport.MSAA_2X if preset==1 else Viewport.MSAA_4X)
 vp.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA if preset==0 else Viewport.SCREEN_SPACE_AA_DISABLED
 vp.use_taa=false
 vp.anisotropic_filtering_level=Viewport.ANISOTROPY_4X if preset<2 else Viewport.ANISOTROPY_16X
 RenderingServer.directional_shadow_atlas_set_size([2048,4096,4096,8192][preset],true)
 RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD,RenderingServer.SHADOW_QUALITY_SOFT_LOW,RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,RenderingServer.SHADOW_QUALITY_SOFT_HIGH][preset])
 RenderingServer.positional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD,RenderingServer.SHADOW_QUALITY_SOFT_LOW,RenderingServer.SHADOW_QUALITY_SOFT_LOW,RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][preset])
 if modern:
  RenderingServer.environment_set_ssao_quality([RenderingServer.ENV_SSAO_QUALITY_VERY_LOW,RenderingServer.ENV_SSAO_QUALITY_MEDIUM,RenderingServer.ENV_SSAO_QUALITY_HIGH,RenderingServer.ENV_SSAO_QUALITY_ULTRA][preset],true,.5,2,50,300)
  RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_32 if preset<3 else RenderingServer.ENV_SDFGI_RAY_COUNT_64)
  RenderingServer.environment_set_volumetric_fog_volume_size(64 if preset<3 else 128,64)
 var sun=game.get_meta('sun',null)
 if sun:
  sun.directional_shadow_max_distance=[70,100,120,150][preset]
  sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if preset==0 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
 # Without GI, a little more sky ambient keeps interiors readable.
 e.ambient_light_energy=.70 if e.sdfgi_enabled else .85
