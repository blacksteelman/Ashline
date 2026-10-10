class_name Art
extends RefCounted
static var materials: Dictionary = {}
static func mat(key: String, color: Color = Color.WHITE, metallic: float = 0.0) -> StandardMaterial3D:
 var cache = key + str(color) + str(metallic)
 if materials.has(cache): return materials[cache]
 var m = StandardMaterial3D.new()
 m.albedo_color = color
 m.roughness = 0.87
 if key in ['concrete','asphalt','brick','metal','plaster']:m.set_meta('surface',key)
 m.metallic = metallic
 if ResourceLoader.exists('res://assets/'+key+'.png'):
  m.albedo_texture = load('res://assets/'+key+'.png')
  m.normal_enabled = true
  m.normal_scale = 0.28
  m.normal_texture = load('res://assets/'+key+'_normal.png')
  m.uv1_scale = Vector3(.38,.76,.38) if key=="brick" else Vector3(0.65,0.65,0.65)
  if ResourceLoader.exists('res://assets/'+key+'_ao.png'):
   m.ao_enabled=true;m.ao_texture=load('res://assets/'+key+'_ao.png');m.ao_light_affect=.3
  m.uv1_triplanar = true
  m.uv1_world_triplanar = true
  m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
  if ResourceLoader.exists('res://assets/'+key+'_roughness.png'):m.roughness_texture=load('res://assets/'+key+'_roughness.png')
 materials[cache] = m
 return m
static func box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, collision: bool = false, surface: String = 'concrete', damaged: bool = true) -> MeshInstance3D:
 var mesh = MeshInstance3D.new()
 var b = BoxMesh.new(); b.size = size; mesh.mesh = b; mesh.material_override = material
 var broken=damaged and collision and surface=='concrete' and size.y>=1.5 and maxf(size.x,size.z)>2.5 and minf(size.x,size.z)<.65
 if broken:
  mesh.mesh=Ruins.wall(size,hash(pos))
  material.cull_mode=BaseMaterial3D.CULL_DISABLED
 parent.add_child(mesh); mesh.position = pos
 if collision:
  var body = StaticBody3D.new(); body.set_meta('surface', material.get_meta('surface',surface) if surface=='concrete' else surface); parent.add_child(body); body.position = pos
  var shape = CollisionShape3D.new(); var s = BoxShape3D.new(); s.size = size; shape.shape = mesh.mesh.create_trimesh_shape() if broken else s
  if broken:shape.shape.backface_collision=true
  body.add_child(shape)
 return mesh
static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material, top: float = -1.0) -> MeshInstance3D:
 var m = MeshInstance3D.new(); var c = CylinderMesh.new(); c.top_radius = radius if top < 0 else top; c.bottom_radius = radius; c.height = height; c.radial_segments = 12; m.mesh = c; m.material_override = material; parent.add_child(m); m.position = pos; return m
static func sphere(parent: Node3D, pos: Vector3, scale_v: Vector3, material: Material) -> MeshInstance3D:
 var m = MeshInstance3D.new(); m.mesh = SphereMesh.new(); m.material_override = material; parent.add_child(m); m.position = pos; m.scale = scale_v; return m
static func text(parent: Node3D, pos: Vector3, words: String, size: int, color: Color) -> Label3D:
 var l = Label3D.new(); l.text = words; l.font_size = size; l.pixel_size = 0.006; l.outline_size=2;l.font=load('res://assets/interface.ttf');l.shaded=true;l.modulate = color; parent.add_child(l); l.position = pos; l.rotation.y=PI; l.double_sided=false; return l
static func world_weapon(parent: Node3D, kind: int) -> Node3D:
 # Third-person copies of the first-person sets, baked offline by tests/bake_world_weapons.gd
 # (socket space: origin at the grip, muzzle -Z, metres) with the muzzle point in a .cfg beside it.
 if Arsenal.WEAPONS[kind].has('fp'):
  var base='res://assets/viewmodels/world_'+Arsenal.WEAPONS[kind].fp.set
  if ResourceLoader.exists(base+'.res'):
   var mi=MeshInstance3D.new();mi.name='WorldWeapon';mi.mesh=load(base+'.res');parent.add_child(mi)
   var meta=ConfigFile.new();meta.load(base+'.cfg')
   mi.set_meta('muzzle',meta.get_value('weapon','muzzle',Vector3(0,.03,-.6)))
   for key in ['grip','support']:
    if meta.has_section_key('weapon',key):mi.set_meta(key,meta.get_value('weapon',key))
   return mi
 # Third-person weapon from the viewmodel pipeline: weapon space, origin at the grip, Muzzle marker.
 var path='res://assets/viewmodels/world_'+Arsenal.WEAPONS[kind].model+'.glb'
 if not ResourceLoader.exists(path):return null
 var scene=load(path).instantiate();parent.add_child(scene)
 var marker=scene.find_child('Muzzle',true,false)
 scene.set_meta('muzzle',marker.position if marker else Vector3(0,.02,-.5))
 return scene
static func weapon(parent: Node3D, kind: int, first_person: bool=true) -> Node3D:
 if ResourceLoader.exists('res://assets/weapon_'+str(kind)+'.glb'):
  var scene=load('res://assets/weapon_'+str(kind)+'.glb').instantiate()
  parent.add_child(scene)
  scene.set_meta('muzzle',Vector3(0,.021,-[.72,.49,.92,.26][kind]*.94))
  if scene.find_child('ViewmodelArms',true,false):
   scene.set_meta('muzzle',Vector3(0,.021,-.565));scene.set_meta('ejector',Vector3(.018,.016,-.078));scene.set_meta('aim_offset',Vector3(0,-.073,-.37))
   scene.set_meta('deforming_arms',true)
  if kind==2:
   var lens=scene.find_child('Lens',true,false)
   if lens:
    var glass=StandardMaterial3D.new();glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.albedo_color=Color(.15,.28,.3,.08);glass.roughness=.1;glass.cull_mode=BaseMaterial3D.CULL_DISABLED;lens.material_override=glass
  if first_person:
   for geometry in scene.find_children('*','MeshInstance3D',true,false):geometry.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;geometry.extra_cull_margin=.8
   for part_name in ['Adjustable stock','Recoil pad','Buffer tube']:
    var part=scene.find_child(part_name,true,false)
    if part:part.visible=false
  if not first_person:
   for part_name in ['LeftHand','LeftSleeve','Trigger hand','Right sleeve','Trigger finger','ViewmodelArms','OperatorForearm.L','OperatorForearm.R','OperatorUpperArm.L','OperatorUpperArm.R']:
    for part in scene.find_children(part_name+'*','Node3D',true,false):part.visible=false
  return scene
 var root = Node3D.new(); parent.add_child(root)
 var steel = mat('gunsteel',Color('#343e40'),.8); var dark = mat('polymer',Color('#171f23')); var tan = mat('gunpaint',Color('#77766a'),.45)
 var length = [0.72,0.49,0.92,0.26][kind]
 box(root,Vector3(0,0,-.12),Vector3(.085,.10,length*.42),steel)
 box(root,Vector3(0,.033,-length*.44),Vector3(.073,.073,length*.36),tan)
 var barrel = cylinder(root,Vector3(0,.025,-length*.72),.013,length*.35,steel); barrel.rotation.x = PI/2
 var muzzle = cylinder(root,Vector3(0,.025,-length*.91),.023,.06,steel); muzzle.rotation.x = PI/2
 box(root,Vector3(0,-.075,-.065),Vector3(.065,.15,.082),dark).rotation.x = -.15
 box(root,Vector3(0,-.07,.06),Vector3(.055,.125,.06),dark).rotation.x = -.28
 box(root,Vector3(0,0,.18),Vector3(.07,.10,.21 if kind!=3 else .04),dark)
 box(root,Vector3(0,-.036,.075),Vector3(.06,.012,.15),steel)
 for i in range(12): box(root,Vector3(0,.078,-.035-i*.023),Vector3(.071,.008,.011),steel)
 for i in range(5): box(root,Vector3(.039,.025,-.15-i*.034),Vector3(.003,.018,.021),dark)
 if kind == 2:
  var scope = cylinder(root,Vector3(0,.12,-.13),.035,.22,steel); scope.rotation.x=PI/2
  box(root,Vector3(0,.082,-.10),Vector3(.035,.03,.12),steel)
 else:
  box(root,Vector3(0,.105,-.07),Vector3(.011,.054,.018),steel)
  box(root,Vector3(0,.105,-.39 if kind!=3 else -.20),Vector3(.01,.039,.013),steel)
 var skin=mat('glove',Color('#5b6358'))
 box(root,Vector3(.058,-.11,.095),Vector3(.073,.07,.11),skin).rotation.x=-.3
 box(root,Vector3(-.054,-.055,-.29 if kind!=3 else -.06),Vector3(.078,.063,.13),skin)
 var sleeve=mat('sleeve',Color('#596252'))
 box(root,Vector3(.09,-.19,.23),Vector3(.10,.10,.23),sleeve).rotation.x=-.4
 box(root,Vector3(-.11,-.14,-.14),Vector3(.10,.10,.23),sleeve).rotation.z=-.35
 root.set_meta('muzzle',Vector3(0,.025,-length*.94))
 return root
static func soldier(parent: Node3D, team: int) -> Node3D:
 var dressed='res://assets/characters/soldier_'+['aegis','ember'][team]+'.glb'
 if ResourceLoader.exists(dressed):
  # MakeHuman soldier (tools/build_soldiers.py): authored facing +Z, the game faces -Z.
  var holder=Node3D.new();holder.name='Soldier';parent.add_child(holder)
  var body=load(dressed).instantiate();body.rotation.y=PI;holder.add_child(body)
  return holder
 if ResourceLoader.exists('res://assets/soldier_'+str(team)+'.glb'):
  var scene=load('res://assets/soldier_'+str(team)+'.glb').instantiate()
  parent.add_child(scene)
  var firearm=weapon(scene,0,false)
  firearm.name='WorldWeapon'
  firearm.position=Vector3(.13,1.18,-.42)
  firearm.scale=Vector3.ONE*.8
  for part in ['LeftHand','LeftSleeve','Trigger hand','Right sleeve']:
   var limb=firearm.find_child(part,true,false)
   if limb:limb.visible=false
  return scene
 var root=Node3D.new();parent.add_child(root)
 var cloth=mat('uniform'+str(team),Color('#596357') if team==0 else Color('#80715b'))
 var vest=mat('vest',Color('#353d38'));var boot=mat('boots',Color('#252a29'));var skin=mat('face',Color('#a68b70'));var accent=mat('team',Color('#63bbc4') if team==0 else Color('#d49868'))
 box(root,Vector3(0,1.14,0),Vector3(.43,.50,.25),cloth)
 box(root,Vector3(0,1.19,-.14),Vector3(.39,.34,.08),vest)
 for x in [-.12,0,.12]:box(root,Vector3(x,1.10,-.20),Vector3(.09,.14,.06),vest)
 box(root,Vector3(0,1.05,.17),Vector3(.30,.36,.14),vest)
 cylinder(root,Vector3(0,1.62,0),.13,.23,skin)
 sphere(root,Vector3(0,1.74,.01),Vector3(.30,.23,.31),vest)
 box(root,Vector3(0,1.65,-.13),Vector3(.23,.06,.02),boot)
 box(root,Vector3(0,1.53,-.14),Vector3(.23,.10,.03),cloth)
 for side in [-1,1]:
  var leg=Node3D.new();root.add_child(leg);leg.position=Vector3(side*.12,.86,0);leg.name='LegL' if side<0 else 'LegR'
  box(leg,Vector3(0,-.20,0),Vector3(.17,.39,.20),cloth)
  box(leg,Vector3(0,-.55,0),Vector3(.15,.32,.17),cloth)
  box(leg,Vector3(0,-.40,-.10),Vector3(.13,.15,.055),vest)
  box(leg,Vector3(0,-.78,-.06),Vector3(.18,.13,.29),boot)
  box(root,Vector3(side*.28,1.25,-.04),Vector3(.16,.30,.17),cloth).rotation.x=-.7
  box(root,Vector3(side*.20,1.08,-.25),Vector3(.14,.15,.32),cloth).rotation.y=side*.6
  box(root,Vector3(side*.30,1.34,-.13),Vector3(.07,.08,.025),accent)
 var gun=weapon(root,0);gun.position=Vector3(.15,1.13,-.33);gun.scale=Vector3.ONE*.8
 return root
