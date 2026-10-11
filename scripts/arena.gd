class_name Arena
extends Node3D
# FOUNDRY DISTRICT: a two-lane urban/industrial TDM map.
# Geometry is authored here; modular CC0 facade and prop kits come from assets/kit.
# Coordinates: X east, Z south(-)/north(+), Aegis deploys south, Ember north.
const MAP_NAME='FOUNDRY DISTRICT'
const BOUNDS=Rect2(-36,-45,72,90)
const CLIP_LAYER=8 # blocks players and bots, not bullets
var obstacles: Array[Rect2]=[]
var spawns=[[],[]]
var patrol: Array[Vector3]=[]
var navigation=AStar3D.new()
var nav_columns: Dictionary={}
var nav_ready=false
# Match the standing fighter hull, with 2 cm of lateral clearance.
const NAV_RADIUS=.32
const NAV_HEIGHT=1.8
const NAV_FLOOR_CLEARANCE=.06 # Capsule clearance above sloped floors.
var kit: Dictionary={}
var facade_meshes: Dictionary={}
var facade_open: Dictionary={}
var lights_root: Node3D
var structure: Node3D
var facade_batches: Dictionary={}
var district_meshes: Dictionary={}
const DISTRICT_COLORS=[Color('#bcb5a4'),Color('#aebbb6'),Color('#c8ba9b'),Color('#aaa8a0')]

func _ready():
 seed(4481)
 kit=JSON.parse_string(FileAccess.get_file_as_string('res://assets/kit/kit.json'))
 load_facade()
 lights_root=Node3D.new();lights_root.name='Lights';add_child(lights_root)
 structure=Node3D.new();structure.name='Structure';add_child(structure)
 build_ground()
 build_apartment_north()
 build_market_south()
 build_foundry_hall()
 build_container_yard()
 build_streets()
 build_district_details()
 build_west_alley()
 build_spawn_zones()
 build_perimeter()
 build_patrol()
 flush_facades()
 if not '--no-batching' in OS.get_cmdline_user_args():StaticBatch.bake(structure)
 # Navigation needs registered physics shapes: build it after the first physics step.
 get_tree().physics_frame.connect(build_navigation,CONNECT_ONE_SHOT)

# ---------------------------------------------------------------- primitives
func solid(pos: Vector3, size: Vector3, key: String, cover: bool=true, yaw: float=0.0, visible_mesh: bool=true, collide: bool=true) -> MeshInstance3D:
 var visual: MeshInstance3D=null
 if visible_mesh:
  visual=MeshInstance3D.new();var b=BoxMesh.new();b.size=size;visual.mesh=b
  var bottom=pos.y-size.y/2
  visual.material_override=Surfaces.get_material(key,floorf((bottom+.5)/3.0)*3.0+.15);structure.add_child(visual)
  visual.position=pos;visual.rotation.y=yaw
 if collide:
  var body=StaticBody3D.new();body.set_meta('surface',Surfaces.surface_of(key));add_child(body);body.position=pos;body.rotation.y=yaw
  var shape=CollisionShape3D.new();var s=BoxShape3D.new();s.size=size;shape.shape=s;body.add_child(shape)
 if cover:add_obstacle(pos,size,yaw)
 return visual

func clip(pos: Vector3, size: Vector3, yaw: float=0.0):
 var body=StaticBody3D.new();body.collision_layer=CLIP_LAYER;body.collision_mask=0;add_child(body);body.position=pos;body.rotation.y=yaw
 var shape=CollisionShape3D.new();var s=BoxShape3D.new();s.size=size;shape.shape=s;body.add_child(shape)

func add_obstacle(pos: Vector3, size: Vector3, yaw: float=0.0):
 # Ground-level cover footprints feed the minimap and bot cover search.
 if pos.y-size.y/2>1.2 or pos.y+size.y/2<.5:return
 var c=absf(cos(yaw));var s=absf(sin(yaw))
 var w=size.x*c+size.z*s;var d=size.x*s+size.z*c
 obstacles.append(Rect2(pos.x-w/2,pos.z-d/2,w,d))

const PROP_SURFACE={'jersey_barrier':'concrete','jersey_barrier_plain':'concrete','cement_bag':'concrete','cardboard_box':'wood','crate_wood':'wood','crate_wood_long':'wood','crate_military':'wood','military_crate':'wood','military_crate_open':'wood','trashbag':'wood','tyre':'wood','plastic_crate':'wood','covered_car':'metal'}
func prop(name: String, pos: Vector3, yaw: float=0.0, collide: bool=true, scale_v: float=1.0) -> Node3D:
 var scene: Node3D=load('res://assets/kit/'+name+'.glb').instantiate()
 add_child(scene);scene.position=pos;scene.rotation.y=yaw;scene.scale=Vector3.ONE*scale_v
 if name.begins_with('fence'):cutout(scene)
 if collide and kit.has(name):
  var lo=Vector3(kit[name].aabb_min[0],kit[name].aabb_min[1],kit[name].aabb_min[2])*scale_v
  var hi=Vector3(kit[name].aabb_max[0],kit[name].aabb_max[1],kit[name].aabb_max[2])*scale_v
  var body=StaticBody3D.new();body.set_meta('surface',PROP_SURFACE.get(name,'metal'));add_child(body)
  body.transform=Transform3D(Basis(Vector3.UP,yaw),pos)
  var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=hi-lo;shape.shape=box;shape.position=(lo+hi)/2;body.add_child(shape)
  add_obstacle(pos+Basis(Vector3.UP,yaw)*((lo+hi)/2),hi-lo,yaw)
 return scene

static var cutout_cache: Dictionary={}
func cutout(scene: Node):
 # Chain-link wire: alpha-tested with alpha-to-coverage instead of sorted blending.
 for mi in scene.find_children('*','MeshInstance3D',true,false):
  for i in range(mi.mesh.get_surface_count()):
   var m=mi.mesh.surface_get_material(i)
   if m is BaseMaterial3D and m.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:
    if not cutout_cache.has(m):
     var c: BaseMaterial3D=m.duplicate();c.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;c.alpha_scissor_threshold=.45
     c.alpha_antialiasing_mode=BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE;c.cull_mode=BaseMaterial3D.CULL_DISABLED;cutout_cache[m]=c
    mi.set_surface_override_material(i,cutout_cache[m])

func lamp(pos: Vector3, energy: float=1.6, range_v: float=9.0, color: Color=Color('#ffd9a8'), shadow: bool=false) -> OmniLight3D:
 # Interior fixtures read as working lights under the ACES grade: brighter, wider, softer falloff.
 var l=OmniLight3D.new();lights_root.add_child(l);l.position=pos;l.light_energy=energy*2.4;l.omni_range=range_v*1.35;l.light_color=color;l.shadow_enabled=shadow;l.omni_attenuation=1.0;l.light_indirect_energy=1.5
 return l

# Box wall from a to b (ground plan) with rectangular openings [u0,u1,v0,v1] measured from a.
func wall(a: Vector3, b: Vector3, height: float, thickness: float, key: String, openings: Array=[]):
 var along=(b-a);var length=along.length();var dir=along/length;var yaw=atan2(-dir.z,dir.x)
 var normal=Vector3(-dir.z,0,dir.x)
 var cuts=openings.duplicate();cuts.sort_custom(func(p,q):return p[0]<q[0])
 var u=0.0
 for o in cuts:
  if o[0]>u+.01:wall_piece(a,dir,yaw,u,o[0],0,height,thickness,key)
  if o[2]>.01:wall_piece(a,dir,yaw,o[0],o[1],0,o[2],thickness,key)
  if o[3]<height-.01:wall_piece(a,dir,yaw,o[0],o[1],o[3],height,thickness,key)
  u=maxf(u,o[1])
 if u<length-.01:wall_piece(a,dir,yaw,u,length,0,height,thickness,key)
 return normal

func wall_piece(a: Vector3, dir: Vector3, yaw: float, u0: float, u1: float, v0: float, v1: float, t: float, key: String):
 var center=a+dir*(u0+u1)/2+Vector3.UP*(v0+v1)/2
 solid(center,Vector3(u1-u0,v1-v0,t),key,v0<.5,yaw)

func stairs(bottom: Vector3, dir: Vector3, run: float, rise: float, width: float, key: String='concrete'):
 # Continuous ramp collider keeps the camera smooth over individual treads.
 var steps=int(round(rise/.2));var yaw=atan2(dir.x,dir.z)
 for i in range(steps):
  var h=rise*(i+1)/steps;var d=run*(i+.5)/steps
  if key=='walkway':solid(bottom+dir*d+Vector3.UP*(h-.035),Vector3(width,.07,run/steps+.035),'steel',false,yaw,true,false)
  else:solid(bottom+dir*d+Vector3.UP*(h/2),Vector3(width,h,run/steps),key,false,yaw,true,false)
 if key=='walkway':
  # Open industrial stair: thin treads on two inclined steel stringers.
  var right=Vector3(dir.z,0,-dir.x)
  for side in [-1.0,1.0]:
   var beam=solid(bottom+dir*run*.5+Vector3.UP*(rise*.5-.16)+right*side*(width*.5-.09),Vector3(.14,.22,sqrt(run*run+rise*rise)),'steel',false,yaw,true,false)
   beam.rotation.x=-atan2(rise,run)
 # Concrete flights keep a solid wedge; the open steel flight uses a thin
 # sloped slab so the space under its high end is genuinely traversable.
 var body=StaticBody3D.new();body.set_meta('surface',Surfaces.surface_of(key));add_child(body)
 body.position=bottom;body.basis=Basis(Vector3.UP,yaw)
 var hw=width/2;var wedge=ConvexPolygonShape3D.new()
 if key=='walkway':
  wedge.points=PackedVector3Array([Vector3(-hw,0,0),Vector3(hw,0,0),Vector3(-hw,rise,run),Vector3(hw,rise,run),Vector3(-hw,-.26,0),Vector3(hw,-.26,0),Vector3(-hw,rise-.26,run),Vector3(hw,rise-.26,run)])
 else:wedge.points=PackedVector3Array([Vector3(-hw,0,0),Vector3(hw,0,0),Vector3(-hw,0,run),Vector3(hw,0,run),Vector3(-hw,rise,run),Vector3(hw,rise,run)])
 var shape=CollisionShape3D.new();shape.shape=wedge;body.add_child(shape)

# ---------------------------------------------------------------- facade kit
func load_facade():
 var scene=load('res://assets/kit/facade.glb').instantiate()
 for node in scene.find_children('*','MeshInstance3D',true,false):facade_meshes[String(node.name)]=node.mesh
 scene.free()
 for key in facade_meshes:
  # Playable windows have broken-out glass; the frame and sill remain.
  var source: Mesh=facade_meshes[key];var stripped=ArrayMesh.new();var had_glass=false
  for i in range(source.get_surface_count()):
   var m=source.surface_get_material(i)
   if m and 'glass' in m.resource_name.to_lower():had_glass=true;continue
   stripped.add_surface_from_arrays(source.surface_get_primitive_type(i),source.surface_get_arrays(i))
   stripped.surface_set_material(stripped.get_surface_count()-1,m)
  if had_glass:facade_open[key]=stripped

func piece(name: String, xform: Transform3D, broken: bool=false, district: int=0):
 if not facade_meshes.has(name):push_warning('Missing facade piece '+name);return
 var mesh: Mesh=facade_open[name] if broken and facade_open.has(name) else facade_meshes[name]
 var variant=str(mesh.get_instance_id())+'/'+str(district)
 if not district_meshes.has(variant):
  var copy: Mesh=mesh.duplicate()
  for i in copy.get_surface_count():
   var original=copy.surface_get_material(i)
   if original is StandardMaterial3D and 'plaster' in original.resource_name.to_lower():
    var plaster=ShaderMaterial.new();plaster.shader=load('res://assets/shaders/facade_weathering.gdshader')
    plaster.set_shader_parameter('albedo_tex',original.albedo_texture)
    plaster.set_shader_parameter('normal_tex',original.normal_texture)
    plaster.set_shader_parameter('normal_scale',original.normal_scale)
    plaster.set_shader_parameter('roughness_tex',original.roughness_texture)
    plaster.set_shader_parameter('roughness_scale',original.roughness)
    plaster.set_shader_parameter('district_color',DISTRICT_COLORS[district])
    copy.surface_set_material(i,plaster)
  district_meshes[variant]=copy
 mesh=district_meshes[variant]
 # Group by mesh and by 24 m cell: instanced draws that still frustum-cull.
 var cell=Vector2i(floori(xform.origin.x/24.0),floori(xform.origin.z/24.0))
 var key=str(mesh.get_instance_id())+'/'+str(cell)
 if not facade_batches.has(key):facade_batches[key]={'mesh':mesh,'xforms':[]}
 facade_batches[key].xforms.append(xform)

func flush_facades():
 for key in facade_batches:
  var batch=facade_batches[key];var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=batch.mesh
  mm.instance_count=batch.xforms.size()
  for i in range(batch.xforms.size()):mm.set_instance_transform(i,batch.xforms[i])
  var node=MultiMeshInstance3D.new();node.multimesh=mm;node.name='Facade';add_child(node)
 facade_batches.clear()

func piece_box(name: String) -> AABB:
 var p=kit.facade.pieces[name];var lo=Vector3(p.aabb_min[0],p.aabb_min[1],p.aabb_min[2]);var hi=Vector3(p.aabb_max[0],p.aabb_max[1],p.aabb_max[2])
 return AABB(lo,hi-lo)

const GROUND_CODES={'D':['wall_door_centered_large_01','',true],'d':['wall_door_centered_large_01','door_centered_large_01',false],'o':['wall_door_offset_small_01','door_offset_small_01',false],'W':['wall_window_centered_large_01','window_centered_large_01',true],'w':['wall_window_centered_small_01','window_centered_small_01',true],'-':['wall_standard_standard_01','',false],'S':['wall_standard_standard_01','',false]}
func upper_code(c: String, floor_i: int, top: bool) -> Array:
 var level='03' if top else '02'
 match c:
  'L':return ['wall_window_centered_large_'+level,'window_centered_large_'+level,true]
  'M':return ['wall_window_centered_small_'+level,'window_centered_small_'+level,true]
  'X':return ['wall_window_centered_double_'+level,'window_centered_double_'+level,true]
  'B':return ['wall_door_window_small_0'+('9' if top else '5'),'door_window_small_0'+('9' if top else '5'),false]
 return ['wall_standard_standard_01','',false]

# Builds a rectangular facade building. plan: {'s':'D-W','n':...} ground codes per side
# (listed in the side's module order), upper: same for upper floors.
# playable floors get interior walls with matching openings; others are sealed volumes.
func building(x0: float, z0: float, x1: float, z1: float, floors: int, plan: Dictionary, upper: Dictionary, playable_floors: int, base_y: float=.15, interior_key: String='plaster_peel'):
 var top=base_y+floors*3.0
 var district=1 if playable_floors==2 else (2 if playable_floors==1 else posmod(int(x0+z0),4))
 var sides={'s':[Vector3(0,0,-1)],'n':[Vector3(0,0,1)],'e':[Vector3(1,0,0)],'w':[Vector3(-1,0,0)]}
 for side in sides:
  var out: Vector3=sides[side][0];var right=Vector3.UP.cross(out)
  var corners=[Vector3(x0,base_y,z0),Vector3(x1,base_y,z0),Vector3(x0,base_y,z1),Vector3(x1,base_y,z1)]
  var on_side=corners.filter(func(c):return absf((c-Vector3((x0+x1)/2,base_y,(z0+z1)/2)).dot(out))>.1 and (c-Vector3((x0+x1)/2,base_y,(z0+z1)/2)).dot(out)>0)
  on_side.sort_custom(func(p,q):return p.dot(right)<q.dot(right))
  var p0: Vector3=on_side[0];var length=(on_side[1]-on_side[0]).length();var count=int(round(length/3.0))
  var basis=Basis(right,Vector3.UP,out)
  var ground: String=plan.get(side,'-'.repeat(count))
  var up_codes: String=upper.get(side,'L'.repeat(count))
  for f in range(floors):
   var y=base_y+f*3.0
   var openings=[]
   for i in range(count):
    var origin=p0+right*3.0*(i+1)+Vector3.UP*(y-base_y)
    var entry=GROUND_CODES.get(ground[i] if i<ground.length() else '-') if f==0 else upper_code(up_codes[i] if i<up_codes.length() else 'L',f,f==floors-1)
    var xf=Transform3D(basis,origin)
    piece(entry[0],xf,false,district)
    var broken=f<playable_floors and f>0
    if entry[1]!='':piece(entry[1],xf,broken)
    var code=ground[i] if i<ground.length() else '-'
    if f==0 and code!='D':piece('base_standard_01',xf)
    elif f==0 and code=='D':
     piece('base_end_02',Transform3D(basis,origin-right*3.0));piece('base_end_01',xf)
    if f==0 and code=='S':prop('shutter_window_graffiti' if (i+hash(side))%2==0 else 'shutter_window',origin+basis*Vector3(-1.5,.95,.16),atan2(out.x,out.z),false)
    if f>0:piece('cornice_standard_standard_01',xf)
    if f<playable_floors and (entry[2] or (entry[1]!='' and f>0)):
     var box=piece_box(entry[1]) if entry[1]!='' else piece_box('door_centered_large_01')
     # Opening measured from the side's start corner (p0) along +right.
     var u0=3.0*(i+1)+box.position.x+.04;var u1=3.0*(i+1)+box.end.x-.04
     var v0=maxf(0,box.position.y+(.02 if box.position.y>.1 else 0));var v1=box.end.y
     openings.append([u0,u1,v0,v1,code if f==0 else 'up'])
   if f<playable_floors:
    var t=.25;var inset=out*-(.02+t/2)
    var a=p0+inset+Vector3.UP*(y-base_y);var b=on_side[1]+inset+Vector3.UP*(y-base_y)
    var cut=[]
    for o in openings:cut.append([o[0],o[1],o[2],o[3]])
    wall(a,b,3.0,t,interior_key,cut)
    for o in openings:
     # Shop windows are looked through, not walked through.
     if o[4] in ['W','w']:
      var mid=(o[0]+o[1])/2;var c=a+right*mid+Vector3.UP*1.5
      clip(c,Vector3(o[1]-o[0],3.0,.3),atan2(-right.z,right.x))
   else:
    # Sealed storey: dark rooms behind the glass, and a solid hull for bullets.
    var inset2=out*-.7
    var a2=p0+inset2+Vector3.UP*(y-base_y);var b2=on_side[1]+inset2+Vector3.UP*(y-base_y)
    solid((a2+b2)/2+Vector3.UP*1.5,Vector3((b2-a2).length()+1.4,3.0,.3),'plaster_dark',false,atan2(-right.z,right.x),true,false)
    solid((p0+on_side[1])/2+out*-.15+Vector3.UP*(y-base_y+1.5),Vector3(length,3.0,.2),'plaster_dark',false,atan2(-right.z,right.x),false,true)
  # Corner piers and roof crown.
  for f in range(floors):piece('wall_pier_corner_02',Transform3D(basis,p0+Vector3.UP*f*3.0))
  piece('crown_pier_corner_02',Transform3D(basis,p0+Vector3.UP*(top-base_y)))
  for i in range(count):
   var o2=p0+right*3.0*(i+1)+Vector3.UP*(top-base_y)
   piece('crown_standard_standard_01',Transform3D(basis,o2))
 # Floor slabs and roof.
 var w=x1-x0;var d=z1-z0;var c=Vector3((x0+x1)/2,0,(z0+z1)/2)
 solid(Vector3(c.x,top-.15,c.z),Vector3(w,.3,d),'concrete',false)
 # Rooftop services break the repeated rectangular skyline. No gameplay hulls.
 prop('duct_fan',Vector3(c.x+.25,top+.3,c.z),-PI/2,false)
 prop('duct_square',Vector3(c.x+1.2,top+.3,c.z),PI/2,false)
 solid(Vector3(c.x-2.0,top+.55,c.z+2.0),Vector3(.7,1.1,.7),'brick_block',false,0,true,false)
 if playable_floors>0:solid(Vector3(c.x,base_y+.01,c.z),Vector3(w-.1,.04,d-.1),'tiles' if interior_key=='plaster_peel' else 'concrete_floor',false)
 for f in range(1,floors):
  if f>=playable_floors+1:break
  # Intermediate slabs are added by the caller when they need stair holes.
 return {'top':top}

# ---------------------------------------------------------------- districts
func build_ground():
 # Asphalt carriageways and raised sidewalks / yards (top at 0.15).
 solid(Vector3(0,-.5,0),Vector3(160,1,180),'road',false)
 # Blocks: [x0,x1,z0,z1]
 for block in [[-36,-6,5,45],[6,36,5,45],[-36,-6,-45,-5],[6,36,-45,-5]]:
  var x0=block[0];var x1=block[1];var z0=block[2];var z1=block[3]
  var street_x=x1 if x1==-6 else x0;var street_z=z0 if z0==5 else z1
  # Sidewalk strips along both streets, yard paving inside.
  solid(Vector3(street_x+(-1.5 if street_x==-6 else 1.5),.075,(z0+z1)/2),Vector3(3,.15,z1-z0),'sidewalk',false)
  var zx0=x0 if street_x==-6 else x0+3;var zx1=x1-3 if street_x==-6 else x1
  solid(Vector3((zx0+zx1)/2,.075,street_z+(1.5 if street_z==5 else -1.5)),Vector3(zx1-zx0,.15,3),'sidewalk',false)
  var yz0=z0+3 if street_z==5 else z0;var yz1=z1 if street_z==5 else z1-3
  solid(Vector3((zx0+zx1)/2,.07,(yz0+yz1)/2),Vector3(zx1-zx0,.14,yz1-yz0),'paving' if x0<0 else 'concrete_floor',false)
  # Curbs: a slightly taller stone edge at the carriageway.
  solid(Vector3(street_x+(-.12 if street_x==-6 else .12),.09,(z0+z1)/2),Vector3(.24,.18,z1-z0),'curb',false)
  solid(Vector3((x0+x1)/2,.09,street_z+(.12 if street_z==5 else -.12)),Vector3(x1-x0,.18,.24),'curb',false)
 # Painted lane markings: worn dashes down the main street and a stop line.
 var paint=ShaderMaterial.new();paint.shader=load('res://assets/shaders/road_paint.gdshader')
 for z in range(-44,45,6):
  if absf(z)<7:continue
  var dash=MeshInstance3D.new();var q=BoxMesh.new();q.size=Vector3(.14,.01,2.4);dash.mesh=q;dash.material_override=paint;add_child(dash);dash.position=Vector3(0,.005,z)
 for z in [-6.2,6.2]:
  var stop=MeshInstance3D.new();var q2=BoxMesh.new();q2.size=Vector3(5.6,.01,.35);stop.mesh=q2;stop.material_override=paint;add_child(stop);stop.position=Vector3(3.0 if z<0 else -3.0,.005,z)

func build_apartment_north():
 # Ashline House: playable two-storey corner block with a stairwell and
 # first-floor rooms overlooking the intersection and the main street.
 var x0=-24.0;var x1=-9.0;var z0=11.0;var z1=26.0
 building(x0,z0,x1,z1,3,{'e':'WWDWw','s':'w-D-W','w':'-SDS-','n':'--o--'},{'e':'LLXLL','s':'MLXLM','w':'MLLLM','n':'MLLLM'},2,.15,'plaster')
 # First-floor slab with stair hole along the north wall.
 var y=3.15
 solid(Vector3((x0+x1)/2,y-.1,(z0+23.6)/2),Vector3(x1-x0,.2,23.6-z0),'concrete',false)
 solid(Vector3((x0+(-21.2))/2,y-.1,(23.6+z1)/2),Vector3(-21.2-x0,.2,z1-23.6),'concrete',false)
 solid(Vector3((-13.8+x1)/2,y-.1,(23.6+z1)/2),Vector3(x1+13.8,.2,z1-23.6),'concrete',false)
 solid(Vector3((x0+x1)/2,y+.012,(z0+23.6)/2),Vector3(x1-x0-.6,.02,23.6-z0-.4),'planks',false,0,true,false)
 solid(Vector3((x0+x1)/2,6.05,(z0+z1)/2),Vector3(x1-x0,.2,z1-z0),'concrete',false)
 # Ceiling of the ground floor (underside), visible from the shop floor.
 stairs(Vector3(-21.0,.17,24.7),Vector3(1,0,0),7.2,y-.17,1.8,'concrete')
 # Stair rail and hole guard upstairs.
 for i in range(5):solid(Vector3(-20.8+i*1.7,y+.5,23.55),Vector3(.05,1.0,.05),'steel',false,0,true,false)
 solid(Vector3(-17.4,y+1.0,23.55),Vector3(7.0,.06,.06),'steel',false,0,true,false)
 clip(Vector3(-17.2,y+.6,23.5),Vector3(7.4,1.2,.1))
 # Ground floor: counter, shelving and a partition with a doorway.
 wall(Vector3(-16.5,.15,11.27),Vector3(-16.5,.15,19.0),3.0,.2,'plaster_peel',[[3.0,4.6,0,2.3]])
 prop('shelves',Vector3(-23.2,.17,14.0),PI/2);prop('shelves',Vector3(-23.2,.17,16.2),PI/2)
 prop('desk',Vector3(-12.6,.17,20.6),PI);prop('cardboard_box',Vector3(-19.8,.17,12.3),.4)
 prop('cardboard_box',Vector3(-20.3,.17,12.9),1.2);prop('crate_wood',Vector3(-14.0,.17,13.1),.2)
 prop('power_box',Vector3(-23.7,1.2,21.0),PI/2,false);prop('extinguisher',Vector3(-9.6,.17,24.9),-PI/2)
 prop('trashbag',Vector3(-22.6,.17,24.6),.8)
 # First floor: two rooms and a corridor; firing positions at the windows.
 wall(Vector3(-16.5,y,11.27),Vector3(-16.5,y,23.4),3.0,.2,'plaster_peel',[[6.0,7.4,0,2.2]])
 prop('desk',Vector3(-11.4,y,15.4),PI/2);prop('military_crate',Vector3(-13.0,y,12.2),.1)
 prop('ammo_box',Vector3(-12.9,y+.27,12.2),.5,false);prop('crate_military',Vector3(-21.6,y,13.0),.3)
 prop('metal_rack',Vector3(-23.4,y,18.4),PI/2);prop('cement_bag',Vector3(-19.0,y,12.0),.2)
 prop('cement_bag',Vector3(-18.6,y,12.1),1.4);prop('jerrycan',Vector3(-10.0,y,22.6),.6)
 for p in [Vector3(-12.8,2.9,15.5),Vector3(-20.0,2.9,17.0),Vector3(-12.8,5.9,17.0),Vector3(-20.0,5.9,16.5)]:
  prop('lamp_hanging',p,0,false,.8);lamp(p-Vector3(0,1.3,0),1.1,7.5,Color('#ffd7a3'),p.y<4)

func build_market_south():
 # Market row: shops on the ground floor, sealed flats above.
 var x0=-27.0;var x1=-9.0;var z0=-26.0;var z1=-11.0
 building(x0,z0,x1,z1,3,{'e':'WDWDW','n':'-SDS-S','w':'S-D-S','s':'-S-S-S'},{'e':'LMLML','n':'MLLLLM','w':'MLLLM','s':'LMXXML'},1,.15,'plaster_peel')
 solid(Vector3((x0+x1)/2,3.05,(z0+z1)/2),Vector3(x1-x0,.2,z1-z0),'concrete',false)
 # Two shops split by a wall with a pass-through.
 wall(Vector3(-18.0,.15,-25.73),Vector3(-18.0,.15,-11.27),3.0,.2,'plaster_peel',[[4.0,5.6,0,2.3],[10.0,11.6,0,2.3]])
 prop('shelves',Vector3(-26.2,.17,-21.0),PI/2);prop('shelves',Vector3(-26.2,.17,-17.8),PI/2)
 prop('metal_rack',Vector3(-20.0,.17,-25.3),0);prop('plastic_crate',Vector3(-23.5,.17,-12.0),.3)
 prop('plastic_crate',Vector3(-23.0,.17,-12.4),1.0);prop('plastic_crate',Vector3(-23.3,.44,-12.2),.6,false)
 prop('desk',Vector3(-13.0,.17,-24.2),0);prop('tool_cart',Vector3(-11.4,.17,-15.0),PI/2)
 prop('crate_wood_long',Vector3(-15.5,.17,-19.0),.3);prop('cardboard_box',Vector3(-21.5,.17,-23.4),.7)
 for p in [Vector3(-22.5,2.95,-18.5),Vector3(-13.5,2.95,-18.5)]:
  prop('fluorescent',p,PI/2,false);lamp(p-Vector3(0,.4,0),1.2,8.0,Color('#e8f0ff'),true)

func build_foundry_hall():
 # Foundry hall: brick plinth, corrugated cladding, three doors and a catwalk.
 var x0=12.0;var x1=33.0;var z0=12.0;var z1=33.0;var h=7.5
 var plinth=1.3
 var doors={'w':[[7.0,12.0,0,4.6]],'s':[[6.0,11.0,0,4.6]],'n':[[15.0,17.0,0,2.5]],'e':[]}
 var sides={'w':[Vector3(x0,.15,z0),Vector3(x0,.15,z1)],'e':[Vector3(x1,.15,z1),Vector3(x1,.15,z0)],'s':[Vector3(x1,.15,z0),Vector3(x0,.15,z0)],'n':[Vector3(x0,.15,z1),Vector3(x1,.15,z1)]}
 for side in sides:
  var a: Vector3=sides[side][0];var b: Vector3=sides[side][1]
  # A low brick course with corrugated steel above, sharing the same openings.
  wall(a,b,plinth,.35,'brick_block',doors[side])
  var upper=[]
  for o in doors[side]:upper.append([o[0],o[1],0,maxf(0,o[3]-plinth)])
  wall(a+Vector3.UP*plinth,b+Vector3.UP*plinth,h-plinth,.18,'corrugated_green' if side in ['w','n'] else 'corrugated',upper)
 # Roof with a long skylight band: sun shafts fall across the hall floor.
 solid(Vector3((x0+x1)/2,h+.2,(z0+18)/2),Vector3(x1-x0+.6,.25,18-z0+.3),'corrugated',false)
 solid(Vector3((x0+x1)/2,h+.2,(21+z1)/2),Vector3(x1-x0+.6,.25,z1-21+.3),'corrugated',false)
 for x in range(13,33,3):solid(Vector3(x,h+.2,19.5),Vector3(.18,.22,3.0),'steel',false,0,true,false)
 solid(Vector3((x0+x1)/2,.16,(z0+z1)/2),Vector3(x1-x0-.4,.04,z1-z0-.4),'concrete_floor',false)
 # Steel portal frames.
 for z in [15.0,19.5,24.0,28.5]:
  for x in [x0+.35,x1-.35]:solid(Vector3(x,h/2,z),Vector3(.3,h,.3),'painted_metal',false,0,true,true)
  solid(Vector3((x0+x1)/2,h-.25,z),Vector3(x1-x0,.35,.3),'painted_metal',false,0,true,false)
 # East catwalk (3.2 m) along the wall, reached by a steel stair from the south.
 var cy=3.2
 solid(Vector3(x1-1.5,cy-.08,25.5),Vector3(2.6,.16,13.0),'walkway',false)
 for z in [19.4,22.5,25.5,28.5,31.6]:solid(Vector3(x1-2.75,cy/2,z),Vector3(.14,cy,.14),'painted_metal',false,0,true,true)
 solid(Vector3(x1-2.75,cy+1.0,25.5),Vector3(.06,.06,13.0),'hazard',false,0,true,false)
 for z in [19.4,22.5,25.5,28.5,31.6]:solid(Vector3(x1-2.75,cy+.5,z),Vector3(.05,1.0,.05),'hazard',false,0,true,false)
 clip(Vector3(x1-2.8,cy+.6,25.5),Vector3(.1,1.2,13.0))
 # Leave a full ground-level entry cell before the ramp. Its former start at
 # z=12.4 put the only grid node above the ramp's inaccessible vertical side.
 stairs(Vector3(x1-1.5,.17,13.2),Vector3(0,0,1),5.8,cy-.17,1.5,'walkway')
 # Overhead crane on the portal frames.
 prop('crane',Vector3((x0+x1)/2,h-.75,22.0),0,false,1.0)
 # Floor: machinery islands that create cover lines across the hall.
 prop('compressor',Vector3(17.0,.17,26.5),.4);prop('generator',Vector3(20.5,.17,17.0),1.2)
 prop('welding_cart',Vector3(14.2,.17,30.6),.3);prop('tool_chest',Vector3(26.0,.17,31.8),PI)
 prop('crate_military',Vector3(23.5,.17,22.0),.2);prop('crate_military',Vector3(23.6,.6,22.1),.25,true)
 prop('military_crate',Vector3(16.0,.17,20.5),1.4);prop('barrel_steel',Vector3(13.2,.17,13.4));prop('barrel_steel',Vector3(13.9,.17,13.2))
 prop('barrel_red',Vector3(13.4,.17,14.1));prop('propane',Vector3(28.6,.17,13.0));prop('lpg_tank',Vector3(29.0,.17,13.4))
 solid(Vector3(21.0,.75,27.5),Vector3(4.0,1.2,1.6),'steel',true)
 solid(Vector3(27.0,.6,18.0),Vector3(1.4,.9,4.0),'rust',true)
 prop('shelves',Vector3(32.4,.17,26.0),-PI/2);prop('metal_rack',Vector3(32.3,cy,20.0),-PI/2)
 prop('crate_wood',Vector3(31.8,cy,24.5),.1);prop('ammo_box',Vector3(31.6,cy+.32,24.5),.3,false)
 for x in [16.5,22.5,28.5]:
  for z in [16.0,27.0]:
   prop('lamp_hanging',Vector3(x,h-.1,z),0,false,1.0);lamp(Vector3(x,h-1.62,z),1.8,11.0,Color('#ffdcae'),x==22.5)
 # Pipes running along the north wall.
 for x in range(14,32,2):prop('pipe_straight',Vector3(x+.98,5.6,z1-.45),0,false).rotation=Vector3(0,0,PI/2)

func container(pos: Vector3, yaw: float, key: String, doors_end: bool=true):
 var size=Vector3(6.06,2.59,2.44)
 solid(pos+Vector3.UP*size.y/2,size,key,true,yaw)
 var b=Basis(Vector3.UP,yaw)
 # Corner posts, top rails and locking bars make the box read as a real ISO container.
 for sx in [-1,1]:
  for sz in [-1,1]:solid(pos+b*Vector3(sx*2.96,1.295,sz*1.15),Vector3(.16,2.6,.16),'steel',false,yaw,true,false)
  solid(pos+b*Vector3(sx*3.04,1.3,0),Vector3(.06,2.45,2.2),key,false,yaw,true,false)
 for sz in [-1,1]:solid(pos+b*Vector3(0,2.55,sz*1.16),Vector3(6.0,.1,.1),'steel',false,yaw,true,false)
 if doors_end:
  for i in range(4):solid(pos+b*Vector3(3.09,1.3,-.85+i*.57),Vector3(.04,2.3,.05),'steel',false,yaw,true,false)

func build_container_yard():
 # SE yard: container lanes, a loading dock and a guard post.
 var reds=['container_red','container_blue','container_tan','container_green']
 var layout=[[Vector3(15.5,.15,-15.5),0.0],[Vector3(15.5,.15,-31.0),0.0],[Vector3(21.0,.15,-23.5),PI/2],
  [Vector3(27.5,.15,-38.0),0.0],[Vector3(14.0,.15,-40.5),PI/2+.06],[Vector3(25.0,.15,-14.5),.08]]
 for i in range(layout.size()):container(layout[i][0],layout[i][1],reds[i%4])
 container(Vector3(15.5,2.74,-31.0),.03,'container_blue',false)
 container(Vector3(27.5,2.74,-38.0),-.04,'container_red',false)
 # Loading dock along the east wall with stairs at its north end.
 var dy=1.25
 solid(Vector3(31.5,dy/2,-26.0),Vector3(5.0,dy,16.0),'concrete_panel',true)
 solid(Vector3(28.95,dy-.05,-26.0),Vector3(.1,.12,16.0),'hazard',false,0,true,false)
 stairs(Vector3(31.5,.15,-15.0),Vector3(0,0,-1),3.0,dy-.15,2.4,'concrete')
 for z in [-31.0,-24.5,-20.0]:prop('crate_wood_long',Vector3(32.2,dy,z),PI/2+.1)
 prop('military_crate',Vector3(30.6,dy,-28.0),.3);prop('barrel_blue',Vector3(33.4,dy,-33.0))
 prop('barrel_blue',Vector3(32.8,dy,-33.4));prop('hand_truck',Vector3(30.0,dy,-22.5),.8,false)
 # Covered vehicles and barrels between the lanes.
 prop('covered_car',Vector3(22.0,.15,-33.0),PI/2+.15)
 for p in [Vector3(19.5,.15,-19.5),Vector3(19.0,.15,-19.0),Vector3(26.6,.15,-27.5)]:prop('barrel_red',p,randf()*TAU)
 prop('tyre',Vector3(24.4,.45,-30.2),0,false).rotation=Vector3(PI/2,0,0)
 prop('wheel_rim',Vector3(24.0,.35,-29.6),0,false).rotation=Vector3(PI/2,.4,0)
 prop('crate_military',Vector3(11.8,.15,-24.0),PI/2);prop('pipe_valve',Vector3(33.6,2.6,-36.0),0,false)
 # Yard fence along the main-street sidewalk with two gaps.
 for z in [-43.0,-41.0,-39.0,-37.0,-29.0,-27.0,-25.0,-17.0,-15.0,-13.0,-11.0]:
  prop('fence_double',Vector3(9.6,.15,z),-PI/2,false)
 for z in [-44.0,-36.0,-30.0,-24.0,-18.0,-10.0]:prop('fence_post',Vector3(9.6,.15,z),0,false)
 for seg in [[-44.0,-36.0],[-30.0,-24.0],[-18.0,-10.0]]:
  var mid=(seg[0]+seg[1])/2;solid(Vector3(9.6,1.25,mid),Vector3(.12,2.4,seg[1]-seg[0]),'steel',false,0,false,true)
 for p in [Vector3(30.0,6.0,-14.0),Vector3(30.0,6.0,-38.0)]:
  prop('security_light',p,PI,false)

func build_streets():
 # Main street: parked/abandoned cars, a barricade checkpoint at the crossing.
 prop('covered_car',Vector3(-4.3,0,-20.0),.04);prop('covered_car',Vector3(4.2,0,-27.0),PI+.08)
 prop('covered_car',Vector3(4.3,0,20.5),PI-.05);prop('covered_car',Vector3(-4.2,0,31.0),-.1)
 prop('covered_car',Vector3(-20.0,0,-3.6),PI/2+.04);prop('covered_car',Vector3(22.0,0,3.5),-PI/2-.06)
 # Jersey barrier chicanes on the approaches and a ring checkpoint at the centre.
 for p in [[Vector3(-2.5,0,-12.0),.05],[Vector3(2.4,0,-14.5),-.1],[Vector3(2.6,0,12.0),PI+.1],[Vector3(-2.2,0,14.4),PI-.05],
  [Vector3(-2.2,0,-1.8),PI/2],[Vector3(2.2,0,1.8),PI/2],[Vector3(-.4,0,2.6),.1],[Vector3(.5,0,-2.6),.05],
  [Vector3(-13.0,0,1.6),PI/2+.1],[Vector3(13.0,0,-1.5),PI/2-.08],[Vector3(-27.5,0,-1.2),PI/2],[Vector3(27.0,0,1.0),PI/2]]:
  prop('jersey_barrier' if randi()%2==0 else 'jersey_barrier_plain',p[0],p[1])
 prop('military_crate',Vector3(1.2,0,.4),.6);prop('crate_military',Vector3(-1.0,0,-.6),.2)
 prop('ammo_box',Vector3(-.8,.42,-.5),1.0,false);prop('jerrycan',Vector3(1.6,0,-.6),.3)
 # Street furniture along both sidewalks.
 for z in [-38.0,-22.0,-9.5,9.5,22.0,38.0]:
  prop('power_pole' if int(z)%2==0 else 'power_pole_b',Vector3(-8.3,.15,z),PI/2,false)
  prop('power_pole_b' if int(z)%2==0 else 'power_pole',Vector3(8.3,.15,z),-PI/2,false)
  for x in [-8.3,8.3]:solid(Vector3(x,3.0,z),Vector3(.24,6.0,.24),'steel',false,0,false,true)
 for p in [Vector3(-8.2,.15,-30.0),Vector3(8.2,.15,28.5),Vector3(-15.5,.15,6.6)]:prop('hydrant',p,randf()*TAU)
 for p in [Vector3(-7.3,.15,-15.0),Vector3(-7.2,.15,-14.3),Vector3(7.3,.15,16.0),Vector3(-7.3,.15,27.5),Vector3(17.0,.15,-7.2)]:
  prop('trash_can',p,randf()*TAU)
 for p in [Vector3(7.4,.15,-6.8),Vector3(-25.0,.15,6.4),Vector3(30.0,.15,-6.7)]:prop('utility_box_wide' if p.x>0 else 'utility_box',p,0 if p.z<0 else PI)
 for p in [Vector3(0,.01,-24.0),Vector3(0,.01,24.0),Vector3(-15.0,.01,0.0),Vector3(16.0,.01,0)]:prop('manhole',p,randf()*TAU,false)
 for p in [Vector3(-7.0,.15,-26.0),Vector3(7.0,.15,24.0),Vector3(-7.4,.15,17.5)]:prop('trashbag',p,randf()*TAU)
 # Cross street: rubble and a sandbag-style cement wall at the east end.
 for i in range(5):prop('cement_bag',Vector3(9.0+i*.62,.15,-5.6),randf_range(-.1,.1),true)
 for i in range(4):prop('cement_bag',Vector3(9.3+i*.62,.33,-5.6),randf_range(-.1,.1),false)
 rubble(Vector3(-4.0,0,-36.0),2.0);rubble(Vector3(3.5,0,37.0),2.2);rubble(Vector3(31.0,.15,6.5),1.6);rubble(Vector3(-31.0,.15,-6.5),1.6)

func rubble(center: Vector3, radius: float):
 for i in range(18):
  var size=Vector3(randf_range(.2,.7),randf_range(.1,.35),randf_range(.2,.6))
  var p=center+Vector3(randf_range(-radius,radius),size.y*.4,randf_range(-radius*.7,radius*.7))
  var m=MeshInstance3D.new();m.mesh=Ruins.fragment(size,hash(p)+i);m.material_override=Surfaces.get_material('concrete' if i%3 else 'brick');structure.add_child(m);m.position=p;m.rotation=Vector3(randf_range(-.3,.3),randf()*TAU,randf_range(-.3,.3))
 solid(center+Vector3(0,.25,0),Vector3(radius*1.4,.5,radius),'concrete',true,0,false,true)

func district_sign(pos: Vector3, yaw: float, title: String, subtitle: String, width: float, color: Color):
 var board=solid(pos,Vector3(width,.85,.10),'painted_metal',false,yaw,true,false)
 # A quiet, matte painted panel: original district lettering, no neon/emission.
 var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.94;board.material_override=mat
 var basis=Basis(Vector3.UP,yaw)
 for row in [[title,.12,130],[subtitle,-.25,32]]:
  var text=Label3D.new();text.text=row[0];text.font_size=row[2];text.pixel_size=.004
  text.modulate=Color('#d4cfb9');text.outline_size=0;text.no_depth_test=false
  text.position=pos+basis*Vector3(0,row[1],.058);text.rotation.y=yaw;add_child(text)

func service_cable(points: PackedVector3Array):
 # Thin catenary-like spans, batched with structure; never obstruct visibility.
 for i in range(points.size()-1):
  var a=points[i];var b=points[i+1];var mesh=MeshInstance3D.new();var rod=CylinderMesh.new()
  rod.top_radius=.012;rod.bottom_radius=.012;rod.height=(b-a).length();rod.radial_segments=5
  mesh.mesh=rod;mesh.material_override=Surfaces.get_material('steel');structure.add_child(mesh)
  mesh.position=(a+b)*.5;mesh.quaternion=Quaternion(Vector3.UP,(b-a).normalized())

func build_district_details():
 var rng=RandomNumberGenerator.new();rng.seed=9014
 district_sign(Vector3(-8.82,2.8,-18.5),PI/2,'ROWAN SUPPLIES','TOOLS  /  HARDWARE  /  EST. 1984',5.8,Color('#394843'))
 district_sign(Vector3(-8.82,2.8,18.5),PI/2,'KELN HOUSE','BLOCK 04  /  RESIDENTIAL',4.8,Color('#484844'))
 district_sign(Vector3(22.5,5.8,11.84),PI,'VORDA METALWORKS','WORKSHOP 02  /  GOODS ENTRANCE',6.6,Color('#464b48'))
 prop('fire_escape',Vector3(-20.0,2.55,10.76),PI,false,.65)
 # Visible external frame and eaves give the hall a constructed silhouette.
 for z in [13.5,17.5,25.5,30.5]:
  solid(Vector3(11.86,4.1,z),Vector3(.12,5.5,.14),'steel',false,0,true,false)
 for x in [13.5,17.0,24.0,28.5,31.5]:
  solid(Vector3(x,4.1,11.86),Vector3(.14,5.5,.12),'steel',false,0,true,false)
 solid(Vector3(11.85,7.48,22.5),Vector3(.18,.18,21.3),'steel',false,0,true,false)
 solid(Vector3(22.5,7.48,11.85),Vector3(21.3,.18,.18),'steel',false,0,true,false)
 # Flush, irregular asphalt repairs. Their perimeter follows the worn pavement
 # rather than reading as another rectangular ground tile. No collision changes.
 for patch in [[Vector3(-2,.014,-24),Vector2(1.8,3.1)],[Vector3(2.7,.014,-9),Vector2(1.5,2.2)],
  [Vector3(-1.2,.014,19),Vector2(2.0,2.6)],[Vector3(-16,.014,0),Vector2(3.0,1.6)],
  [Vector3(17,.014,1),Vector2(2.7,1.8)]]:
  var mesh=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,Surfaces.get_material('asphalt_patch'))
  var ring=PackedVector3Array()
  for i in range(17):
   var angle=(i%16)*TAU/16.0;var radius=rng.randf_range(.88,1.08) if i<16 else 1.0
   ring.append(Vector3(cos(angle)*patch[1].x*radius,0,sin(angle)*patch[1].y*radius))
  ring[16]=ring[0]
  for i in range(16):
   for p in [Vector3.ZERO,ring[i],ring[i+1]]:
    mesh.surface_set_normal(Vector3.UP);mesh.surface_add_vertex(p)
  mesh.surface_end();var node=MeshInstance3D.new();node.mesh=mesh;node.position=patch[0];add_child(node)
 # Services attach to solid facade piers, away from the playable openings.
 for block in [[-8.77,-26.0,-11.0],[-8.77,11.0,26.0]]:
  for z in [block[1]+2.8,block[2]-2.4]:
   for y in [4.2,7.2]:prop('aircon',Vector3(block[0],y,z),PI/2,false)
  for y in [.65,1.65,2.65,3.65,4.65,5.65,6.65,7.65,8.65]:
   prop('gutter_pipe',Vector3(block[0]+.06,y,block[1]+.35),0,false)
  prop('security_light',Vector3(block[0],3.4,(block[1]+block[2])*.5),PI/2,false)
 # Sheltered delivery alcove at the market, outside the doorway.
 solid(Vector3(-8.3,3.3,-24.5),Vector3(1.6,.08,2.3),'corrugated',false,0,true,false)
 for z in [-25.45,-23.55]:
  solid(Vector3(-8.5,3.02,z),Vector3(.85,.08,.08),'steel',false,0,true,false)
 prop('cardboard_box',Vector3(-8.1,.15,-25.0),.2,false)
 prop('hand_truck',Vector3(-8.6,.15,-24.0),PI/2,false)
 # Broken masonry at building edges: shallow fragments without invisible cover.
 for edge in [Vector3(-8.5,.16,-11.8),Vector3(-8.5,.16,25.0),Vector3(12.4,.16,11.2),Vector3(32.0,.16,11.1)]:
  for i in range(12):
   var size=Vector3(rng.randf_range(.08,.26),rng.randf_range(.03,.08),rng.randf_range(.08,.20))
   var m=MeshInstance3D.new();m.mesh=Ruins.fragment(size,i+73);m.material_override=Surfaces.get_material('brick' if i%3 else 'concrete')
   structure.add_child(m);m.position=edge+Vector3(rng.randf_range(-.35,.35),.01,rng.randf_range(-.7,.7));m.rotation.y=rng.randf()*TAU
 # Roof and pole cables, with a modest sag rather than straight floating lines.
 for z in [-22.0,22.0]:
  for offset in [0.0,.22]:
   var span=PackedVector3Array()
   for i in range(13):
    var t=i/12.0;span.append(Vector3(lerpf(-8.3,8.3,t),5.8-sin(t*PI)*.65,z+offset))
   service_cable(span)

func build_west_alley():
 # Service alley behind the two west buildings: dumpster cover and a fence gate.
 for p in [Vector3(-28.0,.15,18.0),Vector3(-27.2,.15,18.3),Vector3(-30.5,.15,-18.0),Vector3(-29.8,.15,-17.6)]:prop('trash_can',p,randf()*TAU)
 for p in [Vector3(-27.6,.15,13.0),Vector3(-31.5,.15,-22.0),Vector3(-28.5,.15,-29.0)]:prop('trashbag',p,randf()*TAU)
 container(Vector3(-31.0,.15,27.5),PI/2+.05,'container_green')
 container(Vector3(-32.5,.15,-36.0),.02,'container_red')
 prop('aircon',Vector3(-24.35,1.6,15.5),-PI/2,false);prop('aircon',Vector3(-24.35,4.4,20.5),-PI/2,false)
 prop('aircon',Vector3(-27.35,1.6,-15.0),-PI/2,false)
 for z in [19.5,-19.0]:
  for i in range(3):prop('gutter_pipe',Vector3(-24.2 if z>0 else -27.2,1.0+i*2.0,z),0,false)
 for p in [Vector3(-30.0,.15,4.0),Vector3(-26.0,.15,32.0),Vector3(-14.0,.15,33.0)]:prop('crate_wood_long',p,randf()*TAU)
 prop('compressor',Vector3(-20.0,.15,31.0),.2);prop('welding_cart',Vector3(-17.5,.15,29.2),1.4)
 # Courtyard fence and gate north of Ashline House.
 for x in [-35.0,-33.0,-31.0,-29.0]:prop('fence_double',Vector3(x,.15,36.0),0,false)
 prop('fence_gate',Vector3(-26.5,.15,36.0),0,false)
 solid(Vector3(-32.0,1.25,36.0),Vector3(8.0,2.4,.12),'steel',false,0,false,true)
 # Parking yard (SW) with covered cars.
 prop('covered_car',Vector3(-31.0,.15,-29.0),.05);prop('covered_car',Vector3(-24.5,.15,-41.0),PI/2+.1)
 prop('covered_car',Vector3(-22.0,.15,-33.5),PI/2-.1)

func build_spawn_zones():
 # Aegis (south) and Ember (north) deploy behind field barricades at the street ends.
 for team in range(2):
  var s=-1.0 if team==0 else 1.0
  for x in [-30.0,-20.0,-4.0,4.0,20.0,30.0]:spawns[team].append(Vector3(x,.3,s*41.5))
  for x in [-12.0,12.0]:spawns[team].append(Vector3(x,.3,s*39.0))
  prop('jersey_barrier',Vector3(-3.5,0,s*35.0),0);prop('jersey_barrier_plain',Vector3(3.0,0,s*34.5),.1)
  prop('military_crate',Vector3(6.6,.15,s*40.0),.2);prop('crate_military',Vector3(-6.8,.15,s*42.0),1.6)
  prop('generator',Vector3(-27.0,.15,s*43.5),PI);prop('jerrycan',Vector3(-26.0,.15,s*43.3),.3)

func backdrop(x0: float, z0: float, x1: float, z1: float, floors: int, face: String):
 # Out-of-bounds apartment blocks: full facade on the play-facing side only.
 var plan={};var upper={}
 for side in ['n','s','e','w']:
  var length=int(round(((x1-x0) if side in ['n','s'] else (z1-z0))/3.0))
  var g='';var u=''
  for i in range(length):
   g+=['-','S','d','W','-','o','w'][(i*3+floors+hash(side))%7]
   u+=['L','M','L','X','L','-'][(i+floors)%6]
  plan[side]=g;upper[side]=u
 building(x0,z0,x1,z1,floors,plan,upper,0)

func build_perimeter():
 # West boundary: three facade blocks; east boundary: warehouse walls.
 backdrop(-48,-30,-36,-6,4,'e');backdrop(-48,6,-36,30,3,'e')
 backdrop(-48,-48,-36,-33,3,'e');backdrop(-48,33,-36,48,4,'e')
 backdrop(36,-48,48,-24,3,'w');backdrop(36,9,48,48,4,'w')
 backdrop(-30,45,-9,57,4,'s');backdrop(9,45,33,57,3,'s')
 backdrop(-30,-57,-9,-45,3,'n');backdrop(9,-57,30,-45,4,'n')
 # Street ends are closed by heavy barricades and razor fencing.
 for s in [-1.0,1.0]:
  for x in [-7.0,-5.0,-3.0,-1.0,1.0,3.0,5.0,7.0]:prop('fence_double',Vector3(x+1.0,0,s*45.6),0 if s>0 else PI,false)
  for x in [-6.0,-2.4,1.2,4.8]:prop('jersey_barrier',Vector3(x,0,s*44.6),randf_range(-.1,.1))
 # Cross street ends east/west.
 for s in [-1.0,1.0]:
  for z in [-5.0,-3.0,-1.0,1.0,3.0]:prop('fence_double',Vector3(s*36.6,0,z+1.0),PI/2 if s>0 else -PI/2,false)
 # Concrete wall between the gaps of the east side.
 solid(Vector3(36.4,2.0,-15.0),Vector3(.5,4.0,18.0),'concrete_panel',false)
 solid(Vector3(36.4,2.0,7.5),Vector3(.5,4.0,3.0),'concrete_panel',false)
 # Invisible play boundary.
 for b in [[Vector3(0,10,BOUNDS.end.y+.5),Vector3(BOUNDS.size.x+4,20,1)],[Vector3(0,10,BOUNDS.position.y-.5),Vector3(BOUNDS.size.x+4,20,1)],
  [Vector3(BOUNDS.end.x+.5,10,0),Vector3(1,20,BOUNDS.size.y+4)],[Vector3(BOUNDS.position.x-.5,10,0),Vector3(1,20,BOUNDS.size.y+4)]]:
  clip(b[0],b[1])
 # Second ring of facade blocks closes every sightline, then low distant mass.
 backdrop(-66,-30,-54,0,5,'e');backdrop(-66,6,-54,36,4,'e');backdrop(54,-36,66,-6,4,'w');backdrop(54,0,66,30,5,'w')
 backdrop(-24,63,0,75,5,'s');backdrop(6,63,30,75,4,'s');backdrop(-30,-75,-6,-63,4,'n');backdrop(3,-75,27,-63,5,'n')
 for i in range(18):
  var angle=i*TAU/18+randf_range(-.06,.06);var r=randf_range(120,150)
  var h=randf_range(14,30);var w=randf_range(16,28)
  var p=Vector3(cos(angle)*r,h/2,sin(angle)*r*1.05)
  solid(p,Vector3(w,h,randf_range(14,22)),'facade_far',false,-angle,true,false)
 for p in [Vector3(-60,0,-70),Vector3(-52,0,-74),Vector3(70,0,60)]:
  var stack=MeshInstance3D.new();var c=CylinderMesh.new();c.top_radius=1.6;c.bottom_radius=2.2;c.height=46;stack.mesh=c;stack.material_override=Surfaces.get_material('brick');add_child(stack);stack.position=p+Vector3.UP*23

func build_patrol():
 patrol.assign([Vector3(0,0,0),Vector3(-4,0,-18),Vector3(4,0,18),Vector3(-12,.2,15),Vector3(-12,3.2,14),Vector3(-20,3.2,20),
  Vector3(-20,.2,18),Vector3(-14,.2,-18),Vector3(-22,.2,-15),Vector3(-30,.2,0),Vector3(-30,.2,22),Vector3(-30,.2,-24),
  Vector3(16,.2,22),Vector3(24,.2,26),Vector3(31.5,3.2,22),Vector3(28,.2,15),Vector3(18,.2,-23),Vector3(24,.2,-31),
  Vector3(31.5,1.3,-28),Vector3(26,.2,-19),Vector3(14,.2,-36),Vector3(20,.2,0),Vector3(-20,.2,0),Vector3(30,.2,8)])

# ---------------------------------------------------------------- navigation
func build_navigation():
 # Sample walkable surfaces from physics so stairs, catwalks and upper floors
 # are navigable exactly where players can stand.
 var space=get_world_3d().direct_space_state
 var capsule=CapsuleShape3D.new();capsule.radius=NAV_RADIUS;capsule.height=NAV_HEIGHT
 var query=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1|CLIP_LAYER
 var id=0;var started=Time.get_ticks_msec()
 for x in range(int(BOUNDS.position.x)+1,int(BOUNDS.end.x)):
  for z in range(int(BOUNDS.position.y)+1,int(BOUNDS.end.y)):
   var top=14.0;var levels=[]
   for k in range(4):
    var ray=PhysicsRayQueryParameters3D.create(Vector3(x,top,z),Vector3(x,-1,z),1)
    var hit=space.intersect_ray(ray)
    if hit.is_empty():break
    if hit.normal.y>.65:
     query.transform=Transform3D(Basis.IDENTITY,hit.position+Vector3.UP*(NAV_HEIGHT*.5+NAV_FLOOR_CLEARANCE))
     if space.intersect_shape(query,1).is_empty():
      navigation.add_point(id,hit.position);levels.append([id,hit.position.y]);id+=1
    top=hit.position.y-.08
   if not levels.is_empty():nav_columns[Vector2i(x,z)]=levels
 for key in nav_columns:
  for entry in nav_columns[key]:
   var a=navigation.get_point_position(entry[0])
   # Two-cell cardinal links bridge thresholds where the wall line itself has no node.
   for d in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(1,-1),Vector2i(2,0),Vector2i(0,2)]:
    var other=key+d
    if not nav_columns.has(other):continue
    var skip=absi(d.x)==2 or absi(d.y)==2
    if skip and column_has(key+d/2,a.y):continue
    for e2 in nav_columns[other]:
     var b=navigation.get_point_position(e2[0])
     # Scale rise allowance with link length so authored ramps stay connected;
     # individual vertical steps are checked separately below.
     var horizontal=Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))
     if absf(a.y-b.y)>horizontal*.7:continue
     if d.x!=0 and d.y!=0 and not (column_has(key+Vector2i(d.x,0),a.y) and column_has(key+Vector2i(0,d.y),a.y)):continue
     # Walk the floor profile: no step between samples may exceed what a player can climb.
     if not floor_profile_ok(space,a,b):continue
     if not edge_clearance_ok(space,a,b,query):continue
     navigation.connect_points(entry[0],e2[0])
 nav_ready=true
 print('NAV_READY points=',navigation.get_point_count(),' ms=',Time.get_ticks_msec()-started)

func edge_clearance_ok(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, query: PhysicsShapeQueryParameters3D) -> bool:
 # Sweep the whole hull, not its centreline: tangent doorway links and corners
 # are otherwise accepted even though a moving fighter clips the jamb.
 # Raise to the higher floor to allow steps already checked by floor_profile_ok.
 var origin=Vector3(a.x,maxf(a.y,b.y)+NAV_HEIGHT*.5+NAV_FLOOR_CLEARANCE,a.z)
 query.transform=Transform3D(Basis.IDENTITY,origin)
 query.motion=Vector3(b.x-a.x,0,b.z-a.z)
 if not space.intersect_shape(query,1).is_empty():return false
 var fractions=space.cast_motion(query)
 return fractions[0]>=.9999

func floor_profile_ok(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> bool:
 var previous=a.y;var top=maxf(a.y,b.y)+.55;var bottom=minf(a.y,b.y)-.6
 for i in range(1,6):
  var p=a.lerp(b,i/5.0)
  var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,top,p.z),Vector3(p.x,bottom,p.z),1))
  if hit.is_empty():return false
  if absf(hit.position.y-previous)>.24:return false
  previous=hit.position.y
 return absf(previous-b.y)<.24

func column_has(c: Vector2i, y: float) -> bool:
 if not nav_columns.has(c):return false
 for e in nav_columns[c]:
  if absf(e[1]-y)<.5:return true
 return false

func route(from: Vector3, to: Vector3) -> PackedVector2Array:
 var result=PackedVector2Array()
 if not nav_ready or navigation.get_point_count()==0:return result
 var start=navigation.get_closest_point(from+Vector3.UP*.1);var end=navigation.get_closest_point(to+Vector3.UP*.1)
 var points=navigation.get_point_path(start,end)
 var space=get_world_3d().direct_space_state
 var hull=CapsuleShape3D.new();hull.radius=.30;hull.height=NAV_HEIGHT
 var query=PhysicsShapeQueryParameters3D.new();query.shape=hull;query.collision_mask=1|CLIP_LAYER
 var entry=navigation.get_point_position(start)
 if points.is_empty() or not (floor_profile_ok(space,from,entry) and edge_clearance_ok(space,from,entry,query)):
  # Combat/separation can push a bot beside a ramp. Project onto a nearby point
  # it can actually approach, not directly onto the ramp's vertical side.
  var candidates=[];var cell=Vector2i(roundi(from.x),roundi(from.z))
  for x in range(-2,3):
   for z in range(-2,3):
    for e in nav_columns.get(cell+Vector2i(x,z),[]):
     var p=navigation.get_point_position(e[0])
     candidates.append({'id':e[0],'point':p,'distance':p.distance_squared_to(from)})
  candidates.sort_custom(func(a,b):return a.distance<b.distance)
  for candidate in candidates:
   if not floor_profile_ok(space,from,candidate.point) or not edge_clearance_ok(space,from,candidate.point,query):continue
   var alternative=navigation.get_point_path(candidate.id,end)
   if alternative.is_empty():continue
   points=alternative;break
 for point in points:result.append(Vector2(point.x,point.z))
 return result

func random_patrol() -> Vector3:return patrol.pick_random()
