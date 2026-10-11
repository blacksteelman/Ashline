class_name ViewmodelMaterial
extends RefCounted
# First-person weapons are drawn with their own field of view and a compressed
# depth range: no fisheye stretching at wide world FOV and no clipping into
# walls, while sharing the scene's lights, shadows, GI and reflections.
const GLOBAL='viewmodel_fov_scale'
static var converted: Dictionary={}

static func ensure_global():
 pass # Declared in project.godot [shader_globals].

static func update_projection(viewmodel_fov: float, camera_fov: float):
 # Ratio of focal lengths: the weapon keeps its own FOV whatever the world FOV is.
 RenderingServer.global_shader_parameter_set(GLOBAL,tan(deg_to_rad(camera_fov)*.5)/tan(deg_to_rad(viewmodel_fov)*.5))

static func apply(root: Node):
 ensure_global()
 for mi in root.find_children('*','MeshInstance3D',true,false):
  var mesh: Mesh=mi.mesh
  if not mesh:continue
  for i in range(mesh.get_surface_count()):
   var source=mi.get_surface_override_material(i)
   if not source:source=mesh.surface_get_material(i)
   if source is BaseMaterial3D:mi.set_surface_override_material(i,convert_material(source))

static func channel(c: int) -> Vector4:
 return [Vector4(1,0,0,0),Vector4(0,1,0,0),Vector4(0,0,1,0),Vector4(0,0,0,1),Vector4(.299,.587,.114,0)][c]

static func convert_material(source: BaseMaterial3D) -> ShaderMaterial:
 if converted.has(source):return converted[source]
 var m=ShaderMaterial.new()
 var glass=source.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA or source.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
 m.shader=load('res://assets/shaders/viewmodel_glass.gdshader' if glass else 'res://assets/shaders/viewmodel.gdshader')
 m.set_shader_parameter('albedo_color',source.albedo_color)
 if source.albedo_texture:m.set_shader_parameter('albedo_tex',source.albedo_texture)
 if source.normal_enabled and source.normal_texture:
  m.set_shader_parameter('use_normal',true);m.set_shader_parameter('normal_tex',source.normal_texture);m.set_shader_parameter('normal_strength',source.normal_scale)
 m.set_shader_parameter('roughness',source.roughness);m.set_shader_parameter('metallic',source.metallic)
 # Keep the imported dielectric response instead of implicitly using the shader default.
 m.set_shader_parameter('specular',source.metallic_specular)
 # Dry cloth/leather are non-metallic, including legacy spec/gloss converted arms.
 # Floors retain texture variation while avoiding mirror-like worn coatings.
 var arms=source.resource_name=='arms'
 m.set_shader_parameter('roughness_floor',.62 if arms else (.0 if glass else .28))
 m.set_shader_parameter('roughness_bias',.16 if arms else (.0 if glass else .12))
 if arms:
  m.set_shader_parameter('metallic',0.0)
  m.set_shader_parameter('specular',.3)
 if source.roughness_texture:
  m.set_shader_parameter('roughness_tex',source.roughness_texture);m.set_shader_parameter('roughness_channel',channel(source.roughness_texture_channel))
 if source.metallic_texture:
  m.set_shader_parameter('metallic_tex',source.metallic_texture);m.set_shader_parameter('metallic_channel',channel(source.metallic_texture_channel))
 if source.ao_enabled and source.ao_texture:
  m.set_shader_parameter('use_ao',true);m.set_shader_parameter('ao_tex',source.ao_texture);m.set_shader_parameter('ao_channel',channel(source.ao_texture_channel))
 if source.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:m.set_shader_parameter('alpha_scissor',source.alpha_scissor_threshold)
 if source.emission_enabled:
  if source.emission_texture:m.set_shader_parameter('emission_tex',source.emission_texture)
  m.set_shader_parameter('emission_color',source.emission);m.set_shader_parameter('emission_energy',maxf(1.0,source.emission_energy_multiplier)*(4.0 if glass else 1.0))
 m.resource_name=source.resource_name
 converted[source]=m
 return m
