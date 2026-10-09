"""Convert licensed CC0 rifle/arms into the authored AR-41 viewmodel.
Original sources and hashes are recorded in thirdparty/SOURCES.json.
Runs after model.py. No source animations are used.
"""
import bpy,math,sys,bmesh
from pathlib import Path
from mathutils import Vector,Matrix
P=Path(__file__).resolve().parent
sys.path.insert(0,str(P))
from biped_pass import orient
bpy.ops.wm.open_mainfile(filepath=str(P/'thirdparty/viewmodel/arms/FPS ARMS RIG 1.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
body=next(o for o in bpy.data.objects if o.type=='MESH')
for o in list(bpy.data.objects):
 if o not in [rig,body]:bpy.data.objects.remove(o,do_unlink=True)
rig.animation_data_clear()
for pb in rig.pose.bones:
 for c in list(pb.constraints):pb.constraints.remove(c)
 pb.matrix_basis=Matrix.Identity(4);pb.rotation_mode='QUATERNION'
bpy.context.view_layer.update()
T=Matrix.Translation((0,-.20,-.35))@Matrix.Diagonal((.105,.105,.105,1))
body_world=body.matrix_world.copy();rig_world=rig.matrix_world.copy()
body.parent=None;body.data.transform(T@body_world);body.matrix_world=Matrix.Identity(4)
rig.data.transform(T@rig_world);rig.matrix_world=Matrix.Identity(4);rig.name='ViewmodelRig';body.name='ViewmodelArms';body.parent=rig
# Bone parent matrices must reflect the baked unit conversion before the first
# IK solve; otherwise the first left-arm key contains a metre-scale offset.
bpy.context.view_layer.update()
# Rebuild the old Blender Internal material as a modern skin surface.
mat=bpy.data.materials.new('Operator field gloves');mat.use_nodes=True;nodes=mat.node_tree.nodes;links=mat.node_tree.links;bsdf=nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.62
tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(P/'field_glove.png'));links.new(tex.outputs['Color'],bsdf.inputs['Base Color']);body.data.materials.clear();body.data.materials.append(mat)
cloth=bpy.data.materials.new('Operator field sleeves');cloth.use_nodes=True;bsdf=cloth.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=(.065,.092,.075,1);bsdf.inputs['Roughness'].default_value=.85
n=cloth.node_tree.nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(P/'cloth_normal.png'));n.image.colorspace_settings.name='Non-Color';normal=cloth.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.22;cloth.node_tree.links.new(n.outputs['Color'],normal.inputs['Color']);cloth.node_tree.links.new(normal.outputs['Normal'],bsdf.inputs['Normal'])
body.data.materials.append(cloth)
# Reuse subtle woven normal detail on the newly derived glove UV finish.
grain=mat.node_tree.nodes.new('ShaderNodeTexImage');grain.image=n.image
glove_normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');glove_normal.inputs['Strength'].default_value=.18
mat.node_tree.links.new(grain.outputs['Color'],glove_normal.inputs['Color']);mat.node_tree.links.new(glove_normal.outputs['Normal'],mat.node_tree.nodes.get('Principled BSDF').inputs['Normal'])
# Retain the licensed hands; the source elbow/wrist transition deformed badly
# under our firing pose. Replace its forearms with newly authored cloth sleeves.
arm_groups={g.index for g in body.vertex_groups if g.name.startswith(('forearm.','upper_arm.','deltoid.','clavicle.'))}
remove=set()
for v in body.data.vertices:
 side='L' if v.co.x<0 else 'R';head=rig.data.bones['hand.'+side].head_local
 forward=(rig.data.bones['f_middle.01.'+side].head_local-head).normalized()
 # Some source forearm vertices have no deform weights; a weight threshold
 # left those as stretched, stationary triangles. Cut at the real wrist plane.
 if (v.co-head).dot(forward)<-.012 or (v.co-head).length>.24:remove.add(v.index)
bm=bmesh.new();bm.from_mesh(body.data);bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.index in remove],context='VERTS');bm.to_mesh(body.data);bm.free()
for face in body.data.polygons:face.material_index=0;face.use_smooth=True
for side,part in [(s,p) for s in ['L','R'] for p in ['forearm','upper_arm']]:
 bone=rig.data.bones[part+'.'+side];basis=bone.matrix_local.to_3x3()
 points=[];faces=[];rings=18;segments=20
 for row in range(rings):
  t=row/(rings-1);radius=((.041*(1-t)+.026*t) if part=='forearm' else (.046*(1-t)+.041*t))*(1+.025*math.sin(t*math.pi*12))
  for col in range(segments):
   angle=col*math.tau/segments
   points.append(bone.head_local+basis@Vector((math.cos(angle)*radius,t*bone.length,math.sin(angle)*radius)))
 for row in range(rings-1):
  for col in range(segments):
   a=row*segments+col;b=row*segments+(col+1)%segments
   faces.append((a,b,b+segments,a+segments))
 mesh=bpy.data.meshes.new('Authored field sleeve');mesh.from_pydata(points,[],faces);mesh.update()
 sleeve=bpy.data.objects.new(('OperatorForearm.' if part=='forearm' else 'OperatorUpperArm.')+side,mesh);bpy.context.collection.objects.link(sleeve);sleeve.parent=rig;mesh.materials.append(cloth)
 group=sleeve.vertex_groups.new(name=part+'.'+side);group.add(list(range(len(points))),1,'REPLACE')
 modifier=sleeve.modifiers.new('Sleeve deformation','ARMATURE');modifier.object=rig
 for face in mesh.polygons:face.use_smooth=True
 uv=mesh.uv_layers.new()
 for face in mesh.polygons:
  for loop_index in face.loop_indices:
   i=mesh.loops[loop_index].vertex_index;uv.data[loop_index].uv=((i%segments)/segments,(i//segments)/(rings-1))
# Discard the source T-pose action; only the authored game clip is exported.
for old in list(bpy.data.actions):bpy.data.actions.remove(old)
# Constraints are baked explicitly, retaining the licensed deforming finger skeleton.
def ik(side,target,palm):
 upper=rig.pose.bones['upper_arm.'+side];fore=rig.pose.bones['forearm.'+side]
 start=upper.bone.head_local.copy();a=upper.bone.length;b=fore.bone.length
 delta=target-start;d=min(delta.length,a+b-.001);direction=delta.normalized();target=start+direction*d
 along=(a*a-b*b+d*d)/(2*d);height=math.sqrt(max(0,a*a-along*along))
 pole=Vector((-.55 if side=='L' else .55,-.10,-.65))-start;bend=(pole-direction*pole.dot(direction)).normalized()
 elbow=start+direction*along+bend*height
 orient(rig,'upper_arm.'+side,start,elbow);orient(rig,'forearm.'+side,elbow,target)
 hand=rig.pose.bones['hand.'+side];head=hand.bone.head_local
 # Resolve roll from real finger landmarks, not the arm's shortest swing.
 longitudinal=(rig.data.bones['f_middle.01.'+side].head_local-head).normalized()
 across=rig.data.bones['f_index.01.'+side].head_local-rig.data.bones['f_pinky.01.'+side].head_local
 across=(across-longitudinal*across.dot(longitudinal)).normalized()
 source=Matrix((across,longitudinal,across.cross(longitudinal))).transposed()
 y=palm.normalized();x=Vector((0,1,0));x=(x-y*x.dot(y)).normalized()
 desired_basis=Matrix((x,y,x.cross(y))).transposed()@source.inverted()@hand.bone.matrix_local.to_3x3()
 desired=Matrix.Translation(target)@desired_basis.to_4x4()
 hand.matrix_basis=hand.bone.convert_local_to_pose(desired,hand.bone.matrix_local,parent_matrix=hand.parent.matrix,parent_matrix_local=hand.parent.bone.matrix_local,invert=True)
 bpy.context.view_layer.update()
 for pb in rig.pose.bones:
  if pb.name.endswith('.'+side) and (pb.name.startswith('f_') or pb.name.startswith('thumb.')):
   curl=(1.15 if '.01.' in pb.name else 1.4) if side=='R' else (.8 if '.01.' in pb.name else 1.05)
   if 'index' in pb.name and side=='R':curl=1.25
   if 'thumb' in pb.name:curl=.35
   if side=='R':curl=-curl
   pb.rotation_mode='XYZ';pb.rotation_euler=(curl,0,0)
 bpy.context.view_layer.update()
 if side=='R':
  finger=rig.pose.bones['f_index.01.R'];head=finger.head.copy()
  orient(rig,'f_index.01.R',head,head+Vector((-.060,.075,-.01)))
 bpy.context.view_layer.update()
def pose(t):
 for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
 bpy.context.view_layer.update()
 target=Vector((-.065,.19,-.047));palm=Vector((.095,.012,.030))
 if t>0:
  reach=min(1,max(0,(t-.04)/.14))*min(1,max(0,(.98-t)/.15));reach=reach*reach*(3-2*reach)
  removed=min(1,max(0,(t-.15)/.18))*min(1,max(0,(.82-t)/.22));removed=removed*removed*(3-2*removed)
  mag=Vector((-.033,.02,-.077))+Vector((-.07,-.04,-.15))*removed
  target=target.lerp(mag,reach);palm=palm.lerp(Vector((.01,.015,-.11)),reach)
 ik('L',target,palm);ik('R',Vector((.035,-.075,-.18)),Vector((-.015,.01,.1)))
action=bpy.data.actions.new('SupportHand_reload_contact');rig.animation_data_create();rig.animation_data.action=None
bpy.context.scene.render.fps=30;bpy.context.scene.frame_start=0;bpy.context.scene.frame_end=60
records={};previous_quaternions={}
for frame in range(61):
 pose(frame/60)
 for side in ['L','R']:
  error=(rig.pose.bones['forearm.'+side].tail-rig.pose.bones['hand.'+side].head).length
  assert error<.005,('Authored pose lost contact',frame,side,error)
 for pb in rig.pose.bones:
  for prop in ['location','rotation_quaternion' if pb.rotation_mode=='QUATERNION' else 'rotation_euler','scale']:
   value=getattr(pb,prop).copy()
   if prop=='rotation_quaternion':
    if pb.name in previous_quaternions and previous_quaternions[pb.name].dot(value)<0:value.negate()
    previous_quaternions[pb.name]=value.copy()
   path='pose.bones["'+pb.name+'"].'+prop
   for i,number in enumerate(value):records.setdefault((path,i),[]).append((frame,number))
# Build curves after solving every pose, keeping Blender animation evaluation
# separate from the manual IK parent-matrix updates.
for (path,index),samples in records.items():
 curve=action.fcurves.new(data_path=path,index=index);curve.keyframe_points.add(len(samples))
 for key,(frame,value) in zip(curve.keyframe_points,samples):key.co=(frame,value);key.interpolation='LINEAR'
pose(0);action.use_fake_user=True
# Sampling the authored clip must reproduce the intended wrist/forearm contact.
rig.animation_data.action=action;bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
for side in ['L','R']:
 error=(rig.pose.bones['forearm.'+side].tail-rig.pose.bones['hand.'+side].head).length
 print('RELOAD_BIND_CONTACT',side,error)
 assert error<.005,'Arm action lost wrist contact while being keyed'
rig.animation_data.action=None;pose(0)
# Import real manufactured geometry, preserving UVs and material maps.
before=set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=str(P/'thirdparty/viewmodel/rifle/M4A1/M4A1.fbx'))
objects=[o for o in bpy.data.objects if o not in before]
finish=bpy.data.materials.new('AR-41 baked PBR');finish.use_nodes=True;nodes=finish.node_tree.nodes;links=finish.node_tree.links;bsdf=nodes.get('Principled BSDF')
for suffix,socket in [('Base_Color','Base Color'),('Metallic','Metallic'),('Roughness','Roughness')]:
 n=nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(P/'thirdparty/viewmodel/rifle/M4A1'/('M4A1_'+suffix+'.png')))
 if suffix!='Base_Color':n.image.colorspace_settings.name='Non-Color'
 links.new(n.outputs['Color'],bsdf.inputs[socket])
n=nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(P/'thirdparty/viewmodel/rifle/M4A1/M4A1_Normal.png'));n.image.colorspace_settings.name='Non-Color';normal=nodes.new('ShaderNodeNormalMap');links.new(n.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bsdf.inputs['Normal'])
mag=bpy.data.objects.new('MagazineRig',None);bpy.context.collection.objects.link(mag)
for o in objects:
 if o.type!='MESH':continue
 name=o.name;world=o.matrix_world.copy();o.parent=None;o.data.transform(Matrix.Translation((.00075,.03,-.012))@world);o.matrix_world=Matrix.Identity(4)
 o.data.materials.clear();o.data.materials.append(finish)
 if name=='Magazine':o.parent=mag
 if name=='Stock':o.name='Adjustable stock'
 if name=='Ejector_2':o.name='Bolt carrier'
for o in objects:
 if o.type=='EMPTY':bpy.data.objects.remove(o,do_unlink=True)
# Rigid meshes can share a material batch while the magazine/bolt stay articulated.
groups={}
for o in list(bpy.data.objects):
 if o.type=='MESH' and o not in [body] and not o.name.startswith(('OperatorForearm.','OperatorUpperArm.')) and o.name not in ['Bolt carrier','Adjustable stock']:
  groups.setdefault(o.parent.name if o.parent else 'root',[]).append(o)
for key,meshes in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in meshes:o.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0]
 if len(meshes)>1:bpy.ops.object.join()
pose(0)
bpy.ops.export_scene.gltf(filepath=str(P/'weapon_0.glb'),export_format='GLB',export_apply=True)
print('AR-41 licensed viewmodel converted')
