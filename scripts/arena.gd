class_name Arena
extends Node3D
var obstacles: Array[Rect2] = []
var grid = AStarGrid2D.new()
var spawns = [[],[]]
func block(pos: Vector3, size: Vector3, m: Material, surface: String='concrete', damaged: bool=true) -> MeshInstance3D:
 var visual=Art.box(self,pos,size,m,true,surface,damaged)
 if pos.y-size.y/2<1.6 and pos.y+size.y/2>.3: obstacles.append(Rect2(Vector2(pos.x-size.x/2-.45,pos.z-size.z/2-.45),Vector2(size.x+.9,size.z+.9)))
 return visual
func _ready():
 seed(4481)
 var concrete=Art.mat('concrete');var brick=Art.mat('brick');var asphalt=Art.mat('asphalt');var metal=Art.mat('metal',Color('#718789'),.55);var plaster=Art.mat('plaster');var dark=Art.mat('charcoal',Color('#2d373a'));var ochre=Art.mat('ochre',Color('#ae8046'));var white=Art.mat('stripe',Color('#c2b99d'))
 Art.box(self,Vector3(0,-.60,0),Vector3(340,.2,340),Art.mat('asphalt',Color('#6a7970')))
 block(Vector3(0,-.25,0),Vector3(64,.5,64),asphalt)
 obstacles.clear()
 for x in [-32,32]:block(Vector3(x,2,0),Vector3(1,4,64),concrete)
 for z in [-32,32]:block(Vector3(0,2,z),Vector3(64,4,1),concrete)
 # Four original walk-through buildings: doorways on both sides and connecting courtyard.
 for x in [-10,10]:
  for z in [-17,17]:
   block(Vector3(x, .05,z),Vector3(11,.1,18),concrete)
   for side in [-1,1]:
    for dz in [-6.5,6.5]:
     # Real 2.7m window opening: collision and geometry agree on the reveal.
     block(Vector3(x+side*5.5,1.075,z+dz),Vector3(.5,2.15,5),brick,'concrete',false)
     block(Vector3(x+side*5.5,4.425,z+dz),Vector3(.5,1.15,5),brick,'concrete',false)
     for jamb in [-1.925,1.925]:block(Vector3(x+side*5.5,3,z+dz+jamb),Vector3(.5,1.7,1.15),brick,'concrete',false)
    block(Vector3(x+side*5.5,4.25,z),Vector3(.5,1.5,8),plaster)
    for dx in [-3.6,3.6]:block(Vector3(x+dx,2.5,z+side*9),Vector3(3.8,5,.5),plaster,'concrete',x<0 and z>0 and side<0)
    block(Vector3(x,4.25,z+side*9),Vector3(3.4,1.5,.5),brick)
   # Broken roof edges, inner pillars, pipes and lit fixtures.
   for dx in [-4.8,4.8]:
    for dz in [-7,7]:block(Vector3(x+dx,2.3,z+dz),Vector3(.45,4.6,.45),concrete)
   Art.box(self,Vector3(x,5.05,z+5),Vector3(11,.22,8),concrete)
   for dz in [-6,0,6]:
    for dx in [-5.8,5.8]:
     var pipe=Art.cylinder(self,Vector3(x+dx,2.6,z+dz),.07,5,metal)
     Art.box(self,Vector3(x+dx*.97,3.45,z+dz),Vector3(.1,.2,1.3),dark)
    var light=OmniLight3D.new();add_child(light);light.position=Vector3(x,3.5,z+dz);light.light_color=Color('#ffcc8c');light.light_energy=.7;light.omni_range=7
   for dz in [-6,4]:
    block(Vector3(x+2, .65,z+dz),Vector3(2.0,1.3,1.0),metal,'metal')
    for i in range(5):Art.box(self,Vector3(x+1.08+i*.45,.65,z+dz-.52),Vector3(.035,1.2,.03),dark)
 # Central landmark: damaged turbine and orange maintenance gantry.
 block(Vector3(-2.8,1.1,0),Vector3(3.8,2.2,4),concrete).visible=false
 var turbine=load('res://assets/turbine.glb').instantiate();add_child(turbine);turbine.position=Vector3(-2.8,0,0)
 for x in [-5,5]:
  Art.cylinder(self,Vector3(x,5,1),.16,10,ochre)
  for h in range(9):Art.box(self,Vector3(x,1+h,1),Vector3(.42,.08,.4),dark)
 Art.box(self,Vector3(0,9.8,1),Vector3(11,.25,.4),ochre)
 Art.box(self,Vector3(0,9.05,1),Vector3(11,.10,.4),ochre)
 for i in range(8):
  var brace=Art.box(self,Vector3(-4.8+i*1.35,9.4,1),Vector3(1.45,.08,.12),ochre);brace.rotation.z=.5 if i%2==0 else -.5
 Art.box(self,Vector3(-2.8,2.3,-2.005),Vector3(2.2,.40,.055),dark)
 Art.text(self,Vector3(-2.8,2.3,-2.04),'TURBINE 04',42,Color('#e5d4ad'))
 # Lane cover, cargo, breached barricades, oil drums.
 for x in [-23,23]:
  for z in [-16,4,18]:
   block(Vector3(x,1.25,z),Vector3(3.5,2.5,5),metal,'metal')
   for i in range(10):Art.box(self,Vector3(x-1.79,1.25,z-2.3+i*.5),Vector3(.06,2.4,.065),dark)
   Art.text(self,Vector3(x,1.5,z-2.64),'AL / 08',32,white.albedo_color)
 for p in [Vector3(3,.65,-8),Vector3(-4,.65,9),Vector3(20,.65,-3),Vector3(-20,.65,11),Vector3(0,.65,22),Vector3(0,.65,-23)]:
  block(p,Vector3(3.8,1.3,.8),concrete)
  for i in range(7):
   var stripe=Art.box(self,p+Vector3(-1.5+i*.5,.1,-.412),Vector3(.22,.85,.02),ochre);stripe.rotation.z=-.45
 for x in [-28,27]:
  for z in [-25,-7,10,24]:
   Art.cylinder(self,Vector3(x,.5,z),.4,1,metal)
   Art.cylinder(self,Vector3(x,1.02,z),.41,.04,dark)
 # Road and pedestrian markings.
 for z in range(-29,30,5):Art.box(self,Vector3(.5,.015,z),Vector3(.12,.015,2),white)
 for x in [-18,18]:
  for z in [-28,28]:
   for i in range(7):Art.box(self,Vector3(x-2.4+i*.8,.017,z),Vector3(.4,.02,3),white)
 for i in range(170):
  var p=Vector3(randf_range(-30,30),.07,randf_range(-30,30))
  if abs(p.x)<5 and abs(p.z)>5:continue
  var debris=Art.box(self,p,Vector3(randf_range(.08,.5),randf_range(.06,.25),randf_range(.08,.45)),concrete);debris.mesh=Ruins.fragment(debris.mesh.size,4481+i);debris.rotation=Vector3(randf()*.3,randf()*6,.1)
 # Skyline, original water tower, cables, lamps, distant industrial silhouettes.
 for i in range(22):
  var x=randf_range(-65,65);var z=-42.0 if i%2==0 else 42.0
  var h=randf_range(8,22);Art.box(self,Vector3(x,h/2,z),Vector3(randf_range(5,10),h,7),plaster)
  for y in range(3,int(h),3):
   for k in range(4):Art.box(self,Vector3(x-2.7+k*1.8,y,z+(-3.55 if z>0 else 3.55)),Vector3(.8,1.2,.05),dark)
 for x in [-28,28]:
  for z in [-26,0,26]:
   Art.cylinder(self,Vector3(x,3.5,z),.10,7,dark)
   Art.box(self,Vector3(x-.7,7,z),Vector3(1.5,.10,.1),dark)
   var lamp=OmniLight3D.new();add_child(lamp);lamp.position=Vector3(x-.7,6.8,z);lamp.light_color=Color('#ffd5a0');lamp.light_energy=1.3;lamp.omni_range=11
 for x in [24,28]:
  for z in [37,41]:Art.cylinder(self,Vector3(x,8,z),.15,16,dark)
 Art.cylinder(self,Vector3(26,16,39),3.5,4,metal)
 Art.text(self,Vector3(26,16,35.48),'ASHLINE\nWATER AUTHORITY',40,Color('#dfd1ae'))
 Art.text(self,Vector3(-10,3.15,-26.40),'FOUNDRY / WEST',42,Color('#e1cda4'))
 Art.text(self,Vector3(10,3.15,-26.40),'RELAY / EAST',42,Color('#8bb9bb'))
 # Accessible maintenance deck, stair ramp and partial industrial railings.
 block(Vector3(26,2.1,-9),Vector3(7,.3,7),metal,'metal')
 for i in range(13):
  Art.box(self,Vector3(26,(i+1)*.0875,-20+i*.6),Vector3(3.0,(i+1)*.175,.62),concrete)
 # A continuous collision ramp keeps fast movement smooth on the visible stair risers.
 var ramp=StaticBody3D.new();add_child(ramp);ramp.position=Vector3(26,1.09,-16.10);ramp.rotation.x=-atan2(2.275,7.8);ramp.set_meta('surface','concrete')
 var ramp_shape=CollisionShape3D.new();var slope=BoxShape3D.new();slope.size=Vector3(3,.12,8.125);ramp_shape.shape=slope;ramp.add_child(ramp_shape)
 for x in [22.7,29.3]:
  for z in [-12,-9,-6]:Art.cylinder(self,Vector3(x,2.7,z),.045,1.1,ochre)
  Art.box(self,Vector3(x,3.2,-9),Vector3(.065,.07,7),ochre)
 Art.box(self,Vector3(26,3.2,-5.7),Vector3(7,.07,.07),ochre)
 # Scorched utility vehicles, broken masonry piles, small street infrastructure.
 for p in [Vector3(-20,0,-5),Vector3(19,0,12),Vector3(4,0,27)]:
  var wreck=load('res://assets/wreck.glb').instantiate();add_child(wreck);wreck.position=p;wreck.rotation.y=.25 if p.x<0 else -.4
  block(p+Vector3(0,.65,0),Vector3(1.9,1.3,3.7),dark,'metal').visible=false
 for p in [Vector3(-15,0,-26),Vector3(15,0,26),Vector3(-6,0,8),Vector3(6,0,-8)]:
  for i in range(22):
   var slab=Art.box(self,p+Vector3(randf_range(-1.6,1.6),randf_range(.05,.55),randf_range(-1.4,1.4)),Vector3(randf_range(.3,1.0),randf_range(.12,.4),randf_range(.3,.8)),brick if i%3==0 else concrete)
   slab.mesh=Ruins.fragment(slab.mesh.size,hash(p)+i)
   slab.rotation=Vector3(randf_range(-.3,.3),randf()*6,randf_range(-.4,.4))
 for x in [-10,10]:
  for z in [-17,17]:
   var bench=load('res://assets/workbench.glb').instantiate();add_child(bench);bench.position=Vector3(x-2.2,.10,z+5.5)
   block(Vector3(x-2.2,.5,z+5.5),Vector3(2.2,1,.8),metal,'metal').visible=false
   var generator=load('res://assets/generator.glb').instantiate();add_child(generator);generator.position=Vector3(x+3,.1,z-3);generator.rotation.y=.2
   block(Vector3(x+3,.6,z-3),Vector3(1.4,1.2,1),metal,'metal').visible=false
   # Floor marking, wall ventilation, fuse cabinets, cable conduits.
   for dx in [-3.5,3.5]:Art.box(self,Vector3(x+dx,.12,z),Vector3(.09,.02,16),ochre)
   Art.box(self,Vector3(x+4.8,1.65,z-6),Vector3(.5,1.1,1.2),metal)
   for i in range(8):Art.box(self,Vector3(x+4.51,1.3+i*.08,z-6),Vector3(.015,.018,.9),dark)
   Art.box(self,Vector3(x-4.4,1.5,z+6),Vector3(.8,1.0,.30),metal)
   Art.text(self,Vector3(x-4.4,1.65,z+5.83),'⚡  415 V',16,Color('#dabf82'))
   for i in range(3):Art.cylinder(self,Vector3(x-4.3+i*.10,3,z+6),.025,3,dark)
 # Smoke at distant fire; original particle motion, outside navigation lanes.
 var plume=CPUParticles3D.new();add_child(plume);plume.position=Vector3(-29,2,35);plume.amount=22;plume.lifetime=7;plume.direction=Vector3.UP;plume.spread=12;plume.initial_velocity_min=1;plume.initial_velocity_max=2;plume.gravity=Vector3(.18,.1,0);plume.scale_amount_min=1.4;plume.scale_amount_max=3
 plume.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var fade=Gradient.new();fade.offsets=PackedFloat32Array([0,.12,.65,1]);fade.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,.65),Color(1,1,1,.42),Color(1,1,1,0)]);plume.color_ramp=fade
 var sm=QuadMesh.new();sm.size=Vector2(3,3)
 var smoke_material=StandardMaterial3D.new();smoke_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;smoke_material.albedo_texture=load('res://assets/smoke.png');smoke_material.albedo_color=Color(.32,.34,.32,.55);smoke_material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;smoke_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;smoke_material.cull_mode=BaseMaterial3D.CULL_DISABLED;sm.material=smoke_material;plume.mesh=sm
 # The district sits in a larger industrial landscape rather than floating in the sky.
 for x in [-46,44]:
  for z in [-20,15,36]:
   Art.box(self,Vector3(x,1.4,z),Vector3(5,2.8,9),metal)
   for i in range(12):Art.box(self,Vector3(x-2.53,1.4,z-4+i*.7),Vector3(.04,2.6,.055),dark)
 for x in [-56,-61]:
  Art.cylinder(self,Vector3(x,12,8),1.1,24,brick)
  Art.cylinder(self,Vector3(x,24.2,8),1.2,.5,dark)
 for z in [-46,46]:
  for x in range(-60,61,6):Art.cylinder(self,Vector3(x,2,z),.045,4,dark)
  Art.box(self,Vector3(0,4,z),Vector3(120,.04,.04),dark)
 DistrictDetail.build(self)
 if not '--no-batching' in OS.get_cmdline_user_args():StaticBatch.bake(self)
 for team in range(2):
  for x in [-27,-18,-3,3,18,27]:spawns[team].append(Vector3(x,.2,-29 if team==0 else 29))
 grid.region=Rect2i(-31,-31,63,63);grid.cell_size=Vector2.ONE;grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
 for x in range(-31,32):
  for z in range(-31,32):
   for r in obstacles:
    if r.has_point(Vector2(x,z)):grid.set_point_solid(Vector2i(x,z));break
func nearest_open(point: Vector2i, physical: Vector3) -> Vector2i:
 point.x=clampi(point.x,-30,30);point.y=clampi(point.y,-30,30)
 if not grid.is_point_solid(point):return point
 var best=point;var dist=999.0
 for dx in range(-4,5):
  for dz in range(-4,5):
   var c=point+Vector2i(dx,dz)
   if grid.is_in_boundsv(c) and not grid.is_point_solid(c) and Vector2(dx,dz).length()<dist:
    var destination=Vector3(c.x,physical.y+.85,c.y)
    var query=PhysicsRayQueryParameters3D.create(physical+Vector3.UP*.85,destination,1)
    if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
     best=c;dist=Vector2(dx,dz).length()
 return best
func route(from: Vector3, to: Vector3) -> PackedVector2Array:
 var a=nearest_open(Vector2i(roundi(from.x),roundi(from.z)),from)
 var b=nearest_open(Vector2i(roundi(to.x),roundi(to.z)),to)
 return grid.get_point_path(a,b,true)
