import bpy, math, random
from mathutils import Vector
from pathlib import Path
P=Path(__file__).resolve().parent
random.seed(33)
def reset():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,c,metal=0,rough=.7):
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True;n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=(*c,1);n.inputs['Metallic'].default_value=metal;n.inputs['Roughness'].default_value=rough
 if any(word in name.lower() for word in ['fabric','ripstop','gloves','nylon']):
  tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(P/'cloth.png'),check_existing=True)
  mix=m.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(*c,1)
  m.node_tree.links.new(tex.outputs['Color'],mix.inputs[1]);m.node_tree.links.new(mix.outputs[0],n.inputs['Base Color'])
 return m
def cube(name,p,s,m,bevel=.025,parent=None,rot=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.name=name;o.dimensions=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  b=o.modifiers.new('Machined / stitched edges','BEVEL');b.width=bevel;b.segments=3;bpy.ops.object.modifier_apply(modifier=b.name)
  o.modifiers.new('Weighted surface normals','WEIGHTED_NORMAL')
 o.data.materials.append(m)
 if rot:o.rotation_euler=rot
 if parent:o.parent=parent
 return o
def ell(name,p,s,m,parent=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=p);o=bpy.context.object;o.name=name;o.scale=s;o.data.materials.append(m)
 for f in o.data.polygons:f.use_smooth=True
 if parent:o.parent=parent
 return o
def cyl(name,p,r,h,m,parent=None,rot=None):
 bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=r,depth=h,location=p);o=bpy.context.object;o.name=name;o.data.materials.append(m)
 b=o.modifiers.new('Edge','BEVEL');b.width=min(.01,r*.2);b.segments=2;bpy.ops.object.modifier_apply(modifier=b.name);o.modifiers.new('Normals','WEIGHTED_NORMAL')
 if rot:o.rotation_euler=rot
 if parent:o.parent=parent
 return o
def tube(name,p,r,inner,h,m):
 vertices=[]
 for y,rad in [(-h/2,r),(h/2,r),(-h/2,inner),(h/2,inner)]:
  for i in range(32):
   a=i*math.tau/32;vertices.append((p[0]+math.cos(a)*rad,p[1]+y,p[2]+math.sin(a)*rad))
 faces=[]
 for i in range(32):
  j=(i+1)%32
  faces.extend([(i,j,32+j,32+i),(64+j,64+i,96+i,96+j),(i,64+i,64+j,j),(32+j,96+j,96+i,32+i)])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.data.materials.append(m);return o
def export(name):bpy.ops.export_scene.gltf(filepath=str(P/name),export_format='GLB',export_apply=True)
# Blender Z up exports to Godot Y up; forward +Y becomes Godot -Z.
for team in range(2):
 reset();cloth=mat('Ripstop / muted field fabric',(.10,.14,.10) if team==0 else (.19,.15,.10));armor=mat('Ballistic nylon',(.105,.135,.115));black=mat('Rubber / dark polymer',(.045,.055,.05));skin=mat('Exposed skin',(.46,.33,.23));goggle=mat('Smoked ballistic lens',(.025,.075,.08),.5,.19);accent=mat('Identification band',(.16,.47,.51) if team==0 else (.62,.32,.12));seam=mat('Seams',(.16,.18,.14));metal=mat('Hardware',(.22,.24,.22),.75,.3)
 ell('Uniform torso',(0,0,1.17),(.24,.16,.31),cloth);ell('Pelvis',(0,0,.88),(.215,.14,.15),cloth)
 cube('Plate carrier',(0,.12,1.20),(.43,.11,.38),armor,.045);cube('Back plate',(0,-.15,1.21),(.39,.12,.39),armor,.035)
 for side in [-1,1]:
  cube('Shoulder strap',(side*.145,0,1.47),(.065,.31,.045),armor,.015)
  cube('Buckle',(side*.145,.17,1.36),(.045,.025,.055),metal,.009)
  ell('Upper arm',(side*.265,.03,1.29),(.10,.11,.20),cloth)
  ell('Elbow',(side*.28,.14,1.12),(.094,.09,.09),armor)
  arm=ell('Forearm',(side*.21,.25,1.13),(.085,.18,.085),cloth);arm.rotation_euler.z=side*.45
  ell('Tactical glove',(side*.14,.39,1.15),(.069,.09,.065),armor)
  cube('Identification',(side*.31,.10,1.35),(.044,.045,.105),accent,.01)
  leg=bpy.data.objects.new('LegL' if side<0 else 'LegR',None);bpy.context.collection.objects.link(leg);leg.location=(side*.115,0,.87)
  ell('Trouser thigh',(0,0,-.18),(.108,.12,.24),cloth,leg)
  cube('Cargo pocket',(side*.09,-.015,-.20),(.045,.16,.18),cloth,.015,leg)
  cube('Pocket flap',(side*.114,0,-.14),(.012,.17,.025),seam,.004,leg)
  ell('Knee',(0,.035,-.42),(.10,.11,.10),cloth,leg);cube('Kneepad',(0,.13,-.43),(.14,.045,.15),armor,.033,leg)
  ell('Trouser calf',(0,-.014,-.58),(.085,.10,.19),cloth,leg)
  cube('Boot',(0,.065,-.79),(.175,.30,.145),black,.035,leg);cube('Sole',(0,.07,-.86),(.18,.31,.028),seam,.008,leg)
  for z in [-.77,-.74,-.71]:cube('Boot lacing',(0,.14,z),(.09,.012,.01),seam,.003,leg)
 cube('Duty belt',(0,0,.92),(.435,.31,.035),black,.015)
 for x in [-.14,0,.14]:
  cube('Magazine pouch',(x,.215,1.12),(.11,.08,.17),cloth,.016);cube('Pouch flap',(x,.26,1.18),(.10,.015,.04),armor,.005)
 for side in [-1,1]:cube('Utility pouch',(side*.24,-.03,1.0),(.095,.17,.14),cloth,.02)
 cyl('Neck',(0,0,1.52),.068,.12,skin)
 ell('Head',(0,.018,1.65),(.115,.105,.145),skin)
 ell('Balaclava',(0,.025,1.61),(.116,.106,.12),cloth)
 ell('Helmet shell',(0,-.015,1.74),(.145,.135,.105),armor)
 cube('Helmet rim',(0,.015,1.71),(.29,.24,.027),armor,.025)
 cube('Ballistic goggles',(0,.115,1.68),(.215,.032,.075),black,.02);cube('Left lens',(-.052,.135,1.68),(.088,.008,.042),goggle,.01);cube('Right lens',(.052,.135,1.68),(.088,.008,.042),goggle,.01)
 for side in [-1,1]:
  cube('Helmet rail',(side*.143,-.018,1.735),(.025,.135,.03),metal,.008)
  cube('Chin strap',(side*.096,.078,1.61),(.015,.015,.18),black,.005)
 cyl('Radio antenna',(-.16,-.20,1.54),.006,.35,black)
 # Worn fabric patches and stitches.
 for i in range(22):
  x=random.uniform(-.18,.18);z=random.uniform(1.0,1.38);cube('Vest stitching',(x,.182,z),(.018,.005,.004),seam,.001)
 for leg_name in ['LegL','LegR']:
  leg=bpy.data.objects.get(leg_name);knee=bpy.data.objects.new('KneeL' if leg_name=='LegL' else 'KneeR',None);bpy.context.collection.objects.link(knee);knee.parent=leg;knee.location=(0,0,-.42)
  for part in list(leg.children):
   if any(part.name.startswith(prefix) for prefix in ['Trouser calf','Kneepad','Boot','Sole']):
    part.parent=knee;part.location.z+=.42
 export('soldier_'+str(team)+'.glb')
# Four distinct, original firearm silhouettes with bevelled metal and individual hardware.
for kind,length in enumerate([.72,.49,.92,.26]):
 reset();steel=mat('Parkerized steel',(.10,.135,.15),.8,.36);poly=mat('Textured polymer',(.045,.055,.053),.05,.72);paint=mat('Cerakote',(.10,.12,.105),.6,.42);bolt=mat('Machined hardware',(.31,.33,.32),.9,.26);glass=mat('Optic glass',(.04,.16,.18),.55,.1);glove=mat('Field gloves',(.075,.10,.075));sleeve=mat('Ripstop sleeve',(.09,.13,.085))
 cube('Receiver',(0,.10,0),(.083,length*.40,.09),steel,.012);cube('Upper receiver',(0,.12,.046),(.077,length*.44,.033),paint,.007)
 cube('Handguard',(0,length*.43,.022),(.075,length*.35,.077),paint,.009)
 cyl('Free floated barrel',(0,length*.72,.021),.012,length*.35,steel,rot=(math.pi/2,0,0));cyl('Muzzle brake',(0,length*.91,.021),.022,.065,steel,rot=(math.pi/2,0,0))
 for side in [-1,1]:
  for i in range(6):cube('MLOK slot',(side*.038,length*.29+i*.027,.018),(.003,.016,.012),poly,.003)
  for i in range(2):cube('Brake port',(side*.022,length*.88+i*.027,.02),(.002,.016,.012),poly,.002)
 cube('Magazine',(0,.07,-.106),(.060,.085,.175 if kind!=3 else .105),poly,.01,rot=(.13,0,0))
 for i in range(4):cube('Magazine ribs',(.032,.074,-.04-i*.035),(.003,.075,.008),paint,.003)
 cube('Pistol grip',(0,-.063,-.092),(.054,.065,.13),poly,.009,rot=(.26,0,0))
 for z in [-.06,-.085,-.11,-.135]:cube('Grip rib',(0,-.10,z),(.056,.007,.008),steel,.002)
 cube('Trigger guard',(0,-.014,-.069),(.044,.072,.010),steel,.004);cube('Trigger',(0,-.015,-.045),(.008,.011,.028),bolt,.003)
 if kind!=3:
  cyl('Buffer tube',(0,-.17,.014),.024,.19,steel,rot=(math.pi/2,0,0));cube('Adjustable stock',(0,-.24,-.009),(.070,.18,.098),poly,.012);cube('Recoil pad',(0,-.334,-.012),(.073,.016,.12),poly,.005)
 for i in range(14 if kind!=3 else 6):cube('Picatinny rail',(0,.025+i*.025,.068),(.070,.011,.008),steel,.002)
 cube('Ejection port',(.044,.12,.016),(.004,.075,.033),poly,.001);cube('Bolt carrier',(.047,.12,.016),(.004,.06,.015),bolt,.001)
 for x in [-.028,.028]:
  for y in [.05,.18]:cyl('Receiver pin',(x,y,.01),.007,.008,bolt,rot=(0,math.pi/2,0))
 if kind==2:
  cube('Optic mount',(0,.10,.086),(.045,.12,.025),steel,.004);tube('Scope tube',(0,.12,.126),.027,.022,.23,steel);tube('Objective',(0,.26,.126),.040,.033,.065,steel);cyl('Lens',(0,.294,.126),.034,.002,glass,rot=(math.pi/2,0,0));cyl('Elevation turret',(0,.13,.169),.018,.03,bolt)
 else:
  for x in [-.025,.025]:cube('Rear sight wing',(x,.042,.10),(.012,.018,.052),steel,.003)
  cube('Rear notch',(0,.042,.085),(.055,.012,.012),steel,.002);cube('Front post',(0,length*.57,.099),(.012,.018,.043),steel,.003)
 cube('Trigger hand',(.042,-.06,-.12),(.075,.10,.05),glove,.018,rot=(.26,0,0))
 cube('Support hand',(-.045,.275 if kind!=3 else .035,-.058),(.075,.10,.047),glove,.017)
 start=Vector((.15,-.24,-.28));end=Vector((.055,-.065,-.14))
 arm=ell('Right sleeve',(start+end)*.5,(.057,.057,(end-start).length*.55),sleeve);arm.rotation_euler=(end-start).to_track_quat('Z','Y').to_euler()
 start=Vector((-.16,-.16,-.25));end=Vector((-.045,.245 if kind!=3 else .02,-.075))
 arm=ell('Left sleeve',(start+end)*.5,(.055,.055,(end-start).length*.51),sleeve);arm.rotation_euler=(end-start).to_track_quat('Z','Y').to_euler()
 for y in [.235,.25,.265]:cube('Glove knuckle',(-.071,y,-.065),(.022,.012,.029),poly,.005)
 # Articulated viewmodel parts remain separate nodes for reload animation.
 for group_name,prefixes in [('MagazineRig',['Magazine']),('LeftHand',['Support hand']),('LeftSleeve',['Left sleeve'])]:
  group=bpy.data.objects.new(group_name,None);bpy.context.collection.objects.link(group)
  for part in list(bpy.context.scene.objects):
   if part!=group and any(part.name.startswith(prefix) for prefix in prefixes):part.parent=group
 # Fingers wrap the handguard, with thumb above the near edge.
 hand=bpy.data.objects.get('LeftHand')
 for finger in range(4):
  ell('Support finger',(-.052,.22+finger*.023,-.035),(.018,.010,.027),glove,hand)
 ell('Support thumb',(-.065,.27,.0),(.015,.042,.014),glove,hand)
 for i in range(4):
  ell('Trigger finger',(.043,-.08+i*.015,-.090),(.013,.012,.028),glove)
 export('weapon_'+str(kind)+'.glb')
# Burned service vehicle, a compact original environmental prop.
reset();body=mat('Burned paint',(.12,.15,.14),.6,.8);rust=mat('Heat exposed steel',(.28,.17,.10),.55,.9);rubber=mat('Tire rubber',(.025,.029,.026));glass=mat('Sooted windows',(.055,.074,.075),.4,.22);metal=mat('Wheel hubs',(.23,.25,.24),.9,.4)
cube('Chassis',(0,0,.55),(1.8,3.6,.5),body,.15);cube('Cabin',(0,-.35,1.17),(1.7,2.3,.8),body,.20);cube('Hood',(0,1.34,.85),(1.7,1.0,.22),rust,.07)
cube('Windshield',(0,.82,1.36),(1.4,.04,.47),glass,.03,rot=(.25,0,0))
for side in [-1,1]:
 for y in [-.90,.25]:cube('Side glass',(side*.856,y,1.37),(.025,.84,.40),glass,.035)
 for y in [-1.25,1.18]:
  cyl('Tire',(side*.9,y,.43),.40,.24,rubber,rot=(0,math.pi/2,0));cyl('Wheel rim',(side*1.025,y,.43),.24,.025,metal,rot=(0,math.pi/2,0))
 for y in [-.9,.25]:cube('Door seam',(side*.905,y,.92),(.012,.98,.015),rust,.004);cube('Handle',(side*.92,y-.26,1.10),(.03,.15,.032),metal,.01)
cube('Bumper',(0,1.86,.47),(1.86,.13,.16),metal,.025)
for x in [-.58,.58]:cube('Broken headlight',(x,1.81,.76),(.37,.05,.17),glass,.035)
for i in range(18):cube('Grille',( -.63+i*.075,1.83,.59),(.018,.02,.16),metal,.003)
export('wreck.glb')
