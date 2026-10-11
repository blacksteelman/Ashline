class_name Surfaces
extends RefCounted
# Runtime PBR materials for authored architecture (ambientCG CC0 sets in assets/textures).
# Each entry: texture key, metres per repeat, tint, physical surface for audio/impacts.
const DEFS={
 'road':['road',4.0,Color(.68,.68,.66),'asphalt',{'grime_strength':0.0,'variation_strength':.22}],
 'asphalt_patch':['asphalt_patch',3.0,Color(.92,.92,.92),'asphalt',{'grime_strength':0.0}],
 'sidewalk':['concrete_floor',2.5,Color(.95,.94,.9),'concrete',{'grime_strength':0.0}],
 'concrete_floor':['concrete_floor',3.0,Color(.86,.86,.84),'concrete',{'grime_strength':0.0}],
 'concrete_panel':['concrete_panel',3.0,Color(.92,.91,.88),'concrete',{}],
 'concrete':['concrete_smooth',2.5,Color(.9,.9,.88),'concrete',{}],
 'curb':['concrete_smooth',1.2,Color(.8,.8,.78),'concrete',{'grime_strength':.5,'grime_height':.25}],
 'brick':['brick_red',2.2,Color(.95,.92,.9),'brick',{}],
 'brick_block':['brick_block',2.0,Color(.85,.85,.82),'brick',{}],
 'plaster_peel':['plaster_peel',1.6,Color(.86,.84,.8),'plaster',{'normal_strength':.8}],
 'plaster':['plaster_clean',2.4,Color(.74,.72,.66),'plaster',{'grime_height':1.0,'variation_strength':.28}],
 'plaster_dark':['plaster_clean',2.4,Color(.45,.47,.45),'plaster',{}],
 'room_paint':['plaster_clean',2.4,Color(.37,.44,.4),'plaster',{'grime_strength':.18,'normal_strength':.45,'roughness_scale':1.15}],
 'gravel':['gravel',2.0,Color(.9,.9,.9),'asphalt',{'grime_strength':0.0}],
 'dirt':['dirt',3.0,Color(.75,.72,.65),'asphalt',{'grime_strength':0.0}],
 'corrugated':['corrugated',2.0,Color(.5,.5,.47),'metal',{'grime_height':1.2,'grime_strength':.5}],
 'corrugated_green':['corrugated_green',2.0,Color(.52,.58,.5),'metal',{'grime_height':1.2,'grime_strength':.45}],
 'container_red':['corrugated',2.4,Color(.62,.24,.17),'metal',{'grime_height':.9}],
 'container_blue':['corrugated',2.4,Color(.2,.33,.45),'metal',{'grime_height':.9}],
 'container_tan':['corrugated',2.4,Color(.66,.56,.4),'metal',{'grime_height':.9}],
 'container_green':['corrugated_green',2.4,Color(.75,.8,.75),'metal',{'grime_height':.9}],
 'painted_metal':['painted_metal',1.5,Color(.48,.51,.48),'metal',{'color_saturation':.18,'roughness_scale':1.2}],
 'hazard':['hazard',1.0,Color(1,1,1),'metal',{}],
 'steel':['metal_plates',2.0,Color(.8,.8,.8),'metal',{'grime_strength':.2}],
 'rust':['rust',1.5,Color(.9,.85,.8),'metal',{}],
 'walkway':['walkway',1.0,Color(.85,.85,.85),'metal',{'grime_strength':0.0}],
 'planks':['planks',1.6,Color(.58,.5,.4),'wood',{'variation_strength':.24}],
 'tiles':['tiles_floor',1.2,Color(.42,.42,.38),'concrete',{'grime_strength':0.0,'roughness_scale':1.4,'variation_strength':.3}],
 'paving':['paving',2.0,Color(.88,.86,.82),'concrete',{'grime_strength':0.0}],
 # The atlas spans six storeys. Nine metres made background windows half-size.
 'facade_far':['facade_windows',18.0,Color(.64,.66,.65),'concrete',{'grime_strength':0.0,'variation_strength':.12,'color_saturation':.35,'roughness_scale':1.2}],
}
static var cache: Dictionary={}
static var variation: Texture2D

static func variation_texture() -> Texture2D:
 if variation:return variation
 var noise=FastNoiseLite.new();noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;noise.frequency=.012;noise.fractal_octaves=4;noise.seed=4481
 var tex=NoiseTexture2D.new();tex.width=256;tex.height=256;tex.seamless=true;tex.noise=noise;tex.generate_mipmaps=true
 variation=tex;return tex

static func get_material(key: String, floor_level: float=0.0) -> Material:
 var cache_key=key+'@'+str(snappedf(floor_level,.01))
 if cache.has(cache_key):return cache[cache_key]
 var d=DEFS[key];var tex=d[0]
 var m=ShaderMaterial.new();m.shader=load('res://assets/shaders/surface.gdshader')
 var albedo='res://assets/textures/'+tex+'_albedo.'+('png' if ResourceLoader.exists('res://assets/textures/'+tex+'_albedo.png') else 'jpg')
 m.set_shader_parameter('albedo_tex',load(albedo))
 m.set_shader_parameter('normal_tex',load('res://assets/textures/'+tex+'_normal.jpg'))
 m.set_shader_parameter('orm_tex',load('res://assets/textures/'+tex+'_orm.jpg'))
 m.set_shader_parameter('variation_tex',variation_texture())
 m.set_shader_parameter('tile_size',d[1]);m.set_shader_parameter('tint',d[2]);m.set_shader_parameter('floor_level',floor_level)
 for k in d[4]:m.set_shader_parameter(k,d[4][k])
 m.set_meta('surface',d[3])
 cache[cache_key]=m;return m

static func surface_of(key: String) -> String:return DEFS[key][3] if DEFS.has(key) else 'concrete'
