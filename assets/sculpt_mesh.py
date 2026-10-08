"""Original cross-section meshes for ASHLINE. No external asset inputs.
Human proportions and manufactured profiles replace placeholder primitives.
"""
import bpy, math
from mathutils import Vector

def remove(prefixes):
 for o in list(bpy.context.scene.objects):
  if o.type=='MESH' and any(o.name.startswith(p) for p in prefixes):bpy.data.objects.remove(o,do_unlink=True)

def mesh(name, verts, faces, material, parent=None, smooth=True):
 data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
 obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);obj.data.materials.append(material)
 if parent:obj.parent=parent
 for face in data.polygons:face.use_smooth=smooth
 # Cylindrical UVs follow the mesh instead of Blender's primitive UV islands.
 uv=data.uv_layers.new(name='Surface')
 for poly in data.polygons:
  for loop in poly.loop_indices:
   v=data.vertices[data.loops[loop].vertex_index].co
   uv.data[loop].uv=(math.atan2(v.y,v.x)/math.tau+.5,v.z*3.0)
 return obj

def loft(name, points, material, parent=None, segments=24, folds=0):
 verts=[];faces=[];previous_u=None
 for j,(p,rx,ry) in enumerate(points):
  p=Vector(p)
  tangent=Vector(points[min(j+1,len(points)-1)][0])-Vector(points[max(0,j-1)][0])
  tangent.normalize();axis=Vector((1,0,0))
  if abs(tangent.dot(axis))>.9:axis=Vector((0,1,0))
  candidate=axis if previous_u is None else previous_u
  u=candidate-tangent*tangent.dot(candidate)
  if u.length<.001:u=axis-tangent*tangent.dot(axis)
  u.normalize();previous_u=u;v=tangent.cross(u).normalized()
  for i in range(segments):
   a=i*math.tau/segments
   ripple=1+folds*(math.sin(j*2.1+a*3)+.4*math.cos(a*7-j))*math.sin(math.pi*j/(len(points)-1))
   verts.append(tuple(p+(u*math.cos(a)*rx+v*math.sin(a)*ry)*ripple))
 for j in range(len(points)-1):
  for i in range(segments):
   k=j*segments+i;n=j*segments+(i+1)%segments
   faces.append((k,n,n+segments,k+segments))
 faces.append(tuple(reversed(range(segments))));faces.append(tuple((len(points)-1)*segments+i for i in range(segments)))
 obj=mesh(name,verts,faces,material,parent)
 distances=[0.0]
 for j in range(1,len(points)):distances.append(distances[-1]+(Vector(points[j][0])-Vector(points[j-1][0])).length)
 uv=obj.data.uv_layers.active
 for face in obj.data.polygons:
  ring_indices=[obj.data.loops[k].vertex_index%segments for k in face.loop_indices]
  seam=0 in ring_indices and segments-1 in ring_indices
  for k in face.loop_indices:
   idx=obj.data.loops[k].vertex_index;ring=idx//segments;around=idx%segments
   u=1.0 if seam and around==0 else around/segments
   uv.data[k].uv=(u,distances[ring]*2.0)
 return obj

def limb(name,start,end,radii,material,parent=None,folds=.07):
 a,b=Vector(start),Vector(end);points=[]
 for j,(rx,ry) in enumerate(radii):points.append((a.lerp(b,j/(len(radii)-1)),rx,ry))
 return loft(name,points,material,parent,24,folds)

def profile(name, sections, material):
 # Octagonal, machined cross-section in X/Z with longitudinal changes in Y.
 verts=[];faces=[]
 for y,width,low,high in sections:
  c=min(.008,width*.18,(high-low)*.22)
  for x,z in [(-width+c,low),(width-c,low),(width,low+c),(width,high-c),(width-c,high),(-width+c,high),(-width,high-c),(-width,low+c)]:verts.append((x,y,z))
 for j in range(len(sections)-1):
  for i in range(8):faces.append((j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i))
 faces.extend([tuple(reversed(range(8))),tuple((len(sections)-1)*8+i for i in range(8))])
 obj=mesh(name,verts,faces,material,smooth=False)
 bevel=obj.modifiers.new('Small machined edges','BEVEL');bevel.width=.0015;bevel.segments=2
 obj.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return obj

def glove(name,center,material,parent,right=False):
 x,y,z=center
 palm=loft(name+' palm',[((x,y-.04,z),.026,.022),((x,y-.02,z),.035,.025),((x,y+.02,z+.003),.038,.025),((x,y+.043,z+.007),.029,.020)],material,parent)
 # Curved fingers have actual knuckles and tapered fingertips, not isolated spheres.
 for i in range(4):
  fy=y-.023+i*.021
  side=-1 if right else 1
  pts=[((x+side*.022,fy,z+.008),.010,.012),((x+side*.040,fy,z+.017),.011,.011),((x+side*.047,fy,z+.037),.010,.010),((x+side*.032,fy,z+.052),.008,.009),((x+side*.019,fy,z+.052),.005,.007)]
  loft(name+' finger '+str(i),pts,material,parent,12)
 loft(name+' thumb',[((x-.015 if right else x+.015,y+.027,z),.015,.014),((x-.036 if right else x+.036,y+.044,z+.015),.013,.012),((x-.026 if right else x+.026,y+.065,z+.030),.010,.010),((x-.012 if right else x+.012,y+.067,z+.031),.006,.007)],material,parent,14)
 return palm

def first_person(kind, glove_mat, sleeve_mat, steel, paint, poly, cube):
 remove(['Trigger hand','Trigger finger','Support hand','Support finger','Support thumb','Glove knuckle','Right sleeve','Left sleeve'])
 left=bpy.data.objects.get('LeftHand');sleeve=bpy.data.objects.get('LeftSleeve')
 cy=.265 if kind!=3 else .035
 # A wide fabric elbow narrows into a wrist; irregular rings form sewn folds.
 arm_mesh=limb('Left sleeve',(-.20,-.38,-.30),(-.067,cy-.052,-.066),[(.075,.070),(.071,.065),(.073,.064),(.065,.062),(.068,.060),(.058,.055),(.056,.054),(.050,.046),(.039,.034)],sleeve_mat,sleeve,.045)
 start=Vector((-.20,-.38,-.30));end=Vector((-.067,cy-.052,-.066))
 q=(end-start).to_track_quat('Z','Y');sleeve.location=start;sleeve.rotation_mode='QUATERNION';sleeve.rotation_quaternion=q
 for vertex in arm_mesh.data.vertices:vertex.co=q.inverted()@(vertex.co-start)
 limb('Left glove cuff',(-.067,cy-.075,-.064),(-.054,cy-.026,-.059),[(.039,.034),(.041,.035),(.040,.034),(.037,.032)],glove_mat,left,.015)
 glove('Support',(-.052,cy,-.056),glove_mat,left)
 limb('Right sleeve',(.21,-.40,-.31),(.050,-.115,-.111),[(.078,.071),(.075,.068),(.069,.065),(.072,.065),(.062,.057),(.055,.050),(.051,.044),(.039,.033)],sleeve_mat,None,.045)
 right=bpy.data.objects.new('Trigger hand',None);bpy.context.collection.objects.link(right)
 limb('Trigger glove cuff',(.050,-.13,-.113),(.045,-.091,-.108),[(.040,.034),(.041,.034),(.039,.033)],glove_mat,right,.01)
 glove('Grip',(.032,-.065,-.107),glove_mat,right,True)
 # Separate curved trigger finger stays outside the trigger while at rest.
 loft('Trigger finger',[((.046,-.055,-.091),.011,.010),((.057,-.033,-.077),.010,.009),((.050,-.010,-.063),.009,.008),((.037,-.008,-.056),.006,.007)],glove_mat,right,12)
 rig_hand(left,"SupportHand")
 rig_hand(right,"TriggerHand")
 if kind==0:
  remove(['Receiver','Upper receiver','Handguard','Picatinny rail','Magazine ribs'])
  profile('Receiver',[(-.09,.029,-.031,.026),(-.060,.041,-.041,.047),(.02,.043,-.042,.047),(.19,.041,-.025,.047),(.25,.032,-.017,.035)],steel)
  profile('Upper receiver',[(-.065,.030,.042,.061),(.16,.032,.045,.061),(.215,.029,.042,.057)],paint)
  profile('Handguard',[ (.22,.037,-.013,.058),(.27,.037,-.013,.058),(.40,.031,-.005,.054),(.47,.027,.001,.049)],paint)
  # Actual ventilation apertures read as recesses with inset dark channels.
  for side in [-1,1]:
   for i in range(6):cube('Vent inset',(side*(.038-i*.001),.258+i*.03,.023),(.002,.018,.014),poly,.003)
  for i in range(17):cube('Picatinny rail',(0,-.037+i*.029,.065),(.058,.012,.008),steel,.0015)
  # Curved magazine body and seams, retained under the reload pivot.
  remove(['Magazine'])
  mag=bpy.data.objects.get('MagazineRig')
  obj=profile('Magazine',[(-.023,.029,-.21,-.045),(.056,.029,-.19,-.035),(.105,.028,-.17,-.033)],poly)
  # Profile is longitudinal; sculpt a tapered curved magazine with a vertical loft instead.
  bpy.data.objects.remove(obj,do_unlink=True)
  obj=loft('Magazine',[((0,.082,-.032),.029,.040),((0,.076,-.077),.028,.042),((0,.055,-.128),.027,.045),((0,.021,-.183),.026,.044),((0,.014,-.198),.027,.045)],poly,mag,16)
  for side in [-1,1]:
   for i in range(3):
    cube('Magazine pressed rib',(side*.028,.021+i*.027,-.126),(.003,.008,.105),paint,.002,mag,rot=(.20,0,0))

def rig_hand(parent, prefix):
 # Deforming hand skeleton, with articulated fingers and a reload release clip.
 objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==parent]
 finger_meshes=[o for o in objects if 'finger' in o.name or 'thumb' in o.name]
 if not finger_meshes:return
 data=bpy.data.armatures.new(prefix+' skeleton');rig=bpy.data.objects.new(prefix+' skeleton',data);bpy.context.collection.objects.link(rig);rig.parent=parent
 bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 palm=data.edit_bones.new('Palm');palm.head=(0,0,0);palm.tail=(0,.06,0)
 bones={}
 for obj in finger_meshes:
  count=14 if 'thumb' in obj.name else 12
  rings=len(obj.data.vertices)//count
  centers=[sum((obj.data.vertices[j*count+i].co for i in range(count)),Vector())/count for j in range(rings)]
  chain=[]
  for j in range(rings-1):
   b=data.edit_bones.new(obj.name+' joint '+str(j));b.head=centers[j];b.tail=centers[j+1];b.parent=palm if j==0 else data.edit_bones[chain[-1]];b.use_connect=j>0;chain.append(b.name)
  bones[obj.name]=(count,chain)
 bpy.ops.object.mode_set(mode='OBJECT')
 for obj in objects:
  mod=obj.modifiers.new('Hand deformation','ARMATURE');mod.object=rig
  if obj.name in bones:
   count,chain=bones[obj.name]
   for j,bone in enumerate(chain):
    group=obj.vertex_groups.new(name=bone)
    ids=list(range(j*count,(j+1)*count))
    if j==len(chain)-1:ids+=list(range((j+1)*count,(j+2)*count))
    group.add(ids,1,'REPLACE')
  else:obj.vertex_groups.new(name='Palm').add(list(range(len(obj.data.vertices))),1,'REPLACE')
 rig.animation_data_create()
 action=bpy.data.actions.new(prefix+'_reload_contact');rig.animation_data.action=action
 for bone in rig.pose.bones:
  if bone.name=='Palm':continue
  bone.rotation_mode='XYZ'
  for frame,angle in [(0,0),(8,-.12),(15,-.22),(24,-.04),(30,0)]:
   bone.rotation_euler.x=angle if 'joint 0' in bone.name else angle*.35
   bone.keyframe_insert(data_path='rotation_euler',frame=frame)
 for bone in rig.pose.bones:bone.rotation_euler=(0,0,0)
 bpy.context.scene.frame_start=0;bpy.context.scene.frame_end=30;bpy.context.scene.render.fps=30
 rig.select_set(False)


def soldier(cloth,armor,skin,black):
 remove(['Plate carrier','Back plate','Balaclava','Duty belt','Uniform torso','Pelvis','Upper arm','Elbow','Forearm','Tactical glove','Trouser thigh','Trouser calf','Knee','Head','Helmet shell','Helmet rim'])
 loft('Fitted ballistic carrier',[((0,.018,1.00),.186,.149),((0,.026,1.065),.210,.170),((0,.026,1.22),.223,.178),((0,.015,1.34),.204,.164),((0,.008,1.405),.157,.128)],armor,folds=.015)
 loft('Balaclava fabric',[((0,.026,1.535),.068,.067),((0,.047,1.575),.085,.081),((0,.03,1.62),.112,.094),((0,.018,1.67),.111,.102)],cloth,segments=28)
 loft('Duty belt',[((0,0,.90),.203,.144),((0,0,.925),.210,.150),((0,0,.945),.207,.147)],black,segments=32)
 loft('Tailored uniform torso',[((0,0,.86),.18,.125),((0,0,.93),.205,.14),((0,-.005,1.08),.202,.15),((0,-.006,1.24),.224,.15),((0,-.012,1.39),.237,.145),((0,-.009,1.47),.17,.10)],cloth,folds=.025)
 for side in [-1,1]:
  leg=bpy.data.objects.get('LegL' if side<0 else 'LegR');knee=bpy.data.objects.get('KneeL' if side<0 else 'KneeR')
  loft('Tailored thigh',[((0,0,.015),.105,.112),((0,.005,-.07),.109,.12),((0,0,-.14),.108,.117),((0,.01,-.23),.097,.107),((0,.007,-.31),.10,.10),((0,.015,-.42),.086,.086)],cloth,leg,folds=.055)
  loft('Tailored shin',[((0,.015,0),.087,.085),((0,-.008,-.05),.087,.086),((0,-.025,-.13),.081,.090),((0,-.01,-.21),.075,.08),((0,-.009,-.30),.067,.071),((0,-.005,-.35),.068,.07)],cloth,knee,folds=.075)
  elbow=(-.25,.20,1.15) if side<0 else (.30,.11,1.12)
  wrist=(.088,.55,1.125) if side<0 else (.156,.29,1.084)
  limb('Uniform upper arm',(side*.245,-.005,1.41),elbow,[(.09,.10),(.104,.10),(.102,.10),(.095,.093),(.089,.08)],cloth,folds=.055)
  limb('Uniform forearm',elbow,wrist,[(.087,.08),(.085,.075),(.081,.07),(.074,.061),(.066,.056)],cloth,folds=.065)
  glove('World glove',(.088,.582,1.125) if side<0 else (.156,.318,1.084),armor,None,right=side>0)
 loft('Human head',[((0,.018,1.53),.067,.067),((0,.031,1.57),.080,.079),((0,.025,1.62),.109,.094),((0,.018,1.70),.106,.103),((0,.004,1.76),.091,.089),((0,0,1.79),.038,.042)],skin)
 loft('Helmet composite shell',[((0,-.009,1.703),.137,.129),((0,-.015,1.72),.145,.135),((0,-.025,1.76),.140,.126),((0,-.021,1.80),.112,.099),((0,-.015,1.83),.067,.066),((0,-.012,1.84),.018,.018)],armor,segments=32)
