"""Original deforming soldier skeleton and keyframed locomotion for ASHLINE.
Runs inside Blender after sculpt_mesh.soldier; no external model/animation inputs.
"""
import bpy, math
from mathutils import Vector, Matrix, Quaternion

POINTS={
 'Hips':((0,0,.88),(0,0,1.03),None),
 'Spine':((0,0,1.03),(0,0,1.25),'Hips'),
 'Chest':((0,0,1.25),(0,0,1.46),'Spine'),
 'Neck':((0,0,1.46),(0,0,1.57),'Chest'),
 'Head':((0,0,1.57),(0,0,1.80),'Neck'),
}
for s,x in [('L',-.115),('R',.115)]:
 POINTS['Thigh.'+s]=((x,0,.87),(x,.015,.45),'Hips')
 POINTS['Shin.'+s]=((x,.015,.45),(x,0,.10),'Thigh.'+s)
 POINTS['Foot.'+s]=((x,0,.10),(x,.21,.07),'Shin.'+s)
 shoulder=(-.245,-.005,1.41) if s=='L' else (.245,-.005,1.41)
 elbow=(-.25,.20,1.15) if s=='L' else (.30,.11,1.12)
 wrist=(.088,.55,1.125) if s=='L' else (.156,.29,1.084)
 POINTS['UpperArm.'+s]=(shoulder,elbow,'Chest')
 POINTS['Forearm.'+s]=(elbow,wrist,'UpperArm.'+s)
 POINTS['Hand.'+s]=(wrist,tuple(Vector(wrist)+Vector((0,.08,0))),'Forearm.'+s)

def clamp(x):return max(0,min(1,x))
def weights(obj, p):
 name=obj.name;side='L' if p.x<0 else 'R'
 if name.startswith(('Tailored thigh','Cargo pocket','Pocket flap')):
  blend=clamp((.52-p.z)/.13) if name.startswith('Tailored thigh') else 0
  return {'Thigh.'+side:1-blend,'Shin.'+side:blend}
 if name.startswith(('Tailored shin','Kneepad','Knee protection')):
  blend=clamp((p.z-.40)/.12) if name.startswith('Tailored shin') else 0
  return {'Shin.'+side:1-blend,'Thigh.'+side:blend}
 if name.startswith(('Boot','Sole')):return {'Foot.'+side:1}
 if name.startswith(('Uniform upper arm','Identification')):
  return {'UpperArm.'+side:1}
 if name.startswith('Uniform forearm'):
  center=obj.data.vertices[len(obj.data.vertices)//2].co
  side='L' if center.x<.10 else 'R'
  a,b=map(Vector,POINTS['Forearm.'+side][:2]);t=clamp((p-a).dot(b-a)/(b-a).length_squared)
  blend=clamp((.20-t)/.20)*.45
  return {'Forearm.'+side:1-blend,'UpperArm.'+side:blend}
 if name.startswith('World glove'):return {'Hand.'+('L' if p.y>.43 else 'R'):1}
 if name.startswith(('Human head','Balaclava','Helmet','Chin strap','Ballistic goggles','Left lens','Right lens')):return {'Head':1}
 if name.startswith('Neck'):return {'Neck':1}
 if name.startswith(('Duty belt','Utility pouch')):return {'Hips':1}
 if name.startswith('Tailored uniform torso'):
  if p.z<1.10:
   t=clamp((p.z-.93)/.17);return {'Hips':1-t,'Spine':t}
  t=clamp((p.z-1.10)/.22);return {'Spine':1-t,'Chest':t}
 return {'Chest':1}

def skin():
 bpy.context.view_layer.update()
 objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
 for obj in objects:
  world=obj.matrix_world.copy();obj.parent=None;obj.data.transform(world);obj.matrix_world=Matrix.Identity(4)
  for group in list(obj.vertex_groups):obj.vertex_groups.remove(group)
 data=bpy.data.armatures.new('Soldier skeleton');rig=bpy.data.objects.new('BipedRig',data);bpy.context.collection.objects.link(rig)
 bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 for name,(head,tail,parent) in POINTS.items():
  bone=data.edit_bones.new(name);bone.head=head;bone.tail=tail
  if parent:bone.parent=data.edit_bones[parent]
 bpy.ops.object.mode_set(mode='OBJECT');rig.select_set(False)
 for obj in objects:
  obj.parent=rig;modifier=obj.modifiers.new('Biped deformation','ARMATURE');modifier.object=rig
  groups={name:obj.vertex_groups.new(name=name) for name in POINTS}
  for v in obj.data.vertices:
   for name,weight in weights(obj,v.co).items():
    if weight>.0001:groups[name].add([v.index],weight,'REPLACE')
 # The old transform-only limb pivots must not survive as a second animation path.
 for obj in list(bpy.context.scene.objects):
  if obj.type=='EMPTY':bpy.data.objects.remove(obj,do_unlink=True)
 animate(rig)
 return rig

def orient(rig,name,head,tail):
 pb=rig.pose.bones[name];rest=pb.bone.matrix_local
 direction=(tail-head).normalized();rest_direction=(pb.bone.tail_local-pb.bone.head_local).normalized()
 rotation=rest_direction.rotation_difference(direction)
 desired=Matrix.Translation(head)@rotation.to_matrix().to_4x4()@rest.to_3x3().to_4x4()
 parent=pb.parent
 pb.matrix_basis=pb.bone.convert_local_to_pose(desired,rest,parent_matrix=parent.matrix if parent else Matrix.Identity(4),parent_matrix_local=parent.bone.matrix_local if parent else Matrix.Identity(4),invert=True)
 bpy.context.view_layer.update()

def leg_ik(rig,side,offset,foot):
 thigh=rig.pose.bones['Thigh.'+side];shin=rig.pose.bones['Shin.'+side]
 hips=rig.pose.bones['Hips'];hip_transform=hips.matrix@hips.bone.matrix_local.inverted()
 hip=hip_transform@Vector(POINTS['Thigh.'+side][0])
 a=(Vector(POINTS['Thigh.'+side][1])-Vector(POINTS['Thigh.'+side][0])).length
 b=(Vector(POINTS['Shin.'+side][1])-Vector(POINTS['Shin.'+side][0])).length
 delta=foot-hip;d=min(delta.length,a+b-.004);direction=delta.normalized()
 foot=hip+direction*d
 along=(a*a-b*b+d*d)/(2*d);height=math.sqrt(max(0,a*a-along*along))
 forward=hip_transform.to_3x3()@Vector((0,1,0));bend=(forward-direction*forward.dot(direction)).normalized()
 knee=hip+direction*along+bend*height
 orient(rig,'Thigh.'+side,hip,knee);orient(rig,'Shin.'+side,knee,foot)
 orient(rig,'Foot.'+side,foot,foot+hip_transform.to_3x3()@Vector((0,.21,-.03)))

def foot_cycle(phase,stride,lift):
 # First half swings forward; second half stays planted relative to a moving root.
 t=(phase/math.tau)%1
 if t<.5:
  v=t*2;travel=-stride+2*stride*(v*v*(3-2*v));height=lift*math.sin(v*math.pi)
 else:travel=stride-4*stride*(t-.5);height=0
 return travel,height

def reload_arm(rig,t):
 rest=Vector(POINTS['Hand.L'][0])
 mag=Vector((.088,.37,1.07-.056*math.sin(math.pi*t)))
 points=[(0,rest),(.20,mag),(.48,mag),(.62,Vector((.035,.25,1.065))),(.76,mag),(.9,rest),(1,rest)]
 target=rest
 for i in range(len(points)-1):
  start,a=points[i];end,b=points[i+1]
  if start<=t<=end:
   u=(t-start)/(end-start);target=a.lerp(b,u*u*(3-2*u));break
 chest=rig.pose.bones['Chest'];transform=chest.matrix@chest.bone.matrix_local.inverted()
 shoulder=transform@Vector(POINTS['UpperArm.L'][0]);target=transform@target
 a=(Vector(POINTS['UpperArm.L'][1])-Vector(POINTS['UpperArm.L'][0])).length
 b=(Vector(POINTS['Forearm.L'][1])-Vector(POINTS['Forearm.L'][0])).length
 direction=(target-shoulder).normalized();d=min((target-shoulder).length,a+b-.004)
 target=shoulder+direction*d;along=(a*a-b*b+d*d)/(2*d)
 # Keep the elbow outside/down from the weapon, rather than through the torso.
 pole=transform.to_3x3()@Vector((-1,0,-.7));bend=(pole-direction*pole.dot(direction)).normalized()
 elbow=shoulder+direction*along+bend*math.sqrt(max(0,a*a-along*along))
 orient(rig,'UpperArm.L',shoulder,elbow);orient(rig,'Forearm.L',elbow,target)
 orient(rig,'Hand.L',target,target+transform.to_3x3()@Vector((0,.08,0)))

def animate(rig):
 rig.animation_data_create();scene=bpy.context.scene;scene.render.fps=30
 clips=[('Idle_loop',60,'idle'),('Forward_loop',24,'forward'),('Backward_loop',24,'back'),('Left_loop',24,'left'),('Right_loop',24,'right'),('Sprint_loop',20,'sprint'),('CrouchIdle_loop',60,'crouchidle'),('CrouchWalk_loop',28,'crouchwalk'),('Jump',24,'jump'),('Reload',60,'reload'),('Death',30,'death')]
 for name,frames,mode in clips:
  action=bpy.data.actions.new(name);rig.animation_data.action=action
  for frame in range(frames+1):
   scene.frame_set(frame);phase=frame/frames*math.tau
   for pb in rig.pose.bones:pb.rotation_mode='QUATERNION';pb.matrix_basis=Matrix.Identity(4)
   offset=Vector((0,0,0));hips=rig.pose.bones['Hips']
   crouch=mode in ['crouchidle','crouchwalk']
   if crouch:offset.z=-.55
   elif mode in ['idle','reload']:offset.z=.003*math.sin(phase)
   else:offset.z=(-.14 if mode=="sprint" else -.09)+.008*math.cos(phase*2)
   # Root bone axes are converted explicitly, rather than assuming Blender pose Y is world Y.
   hips.location=hips.bone.matrix_local.to_3x3().inverted()@offset
   side_yaw=math.radians(60)*(1 if mode=='left' else -1) if mode in ['left','right'] else 0
   if side_yaw:
    hips.rotation_quaternion=Quaternion((0,1,0),side_yaw)
    rig.pose.bones['Spine'].rotation_quaternion=Quaternion((0,1,0),-side_yaw)
   chest=rig.pose.bones['Chest'];chest.rotation_quaternion=Quaternion((1,0,0),-.09 if crouch else (-.10 if mode=='sprint' else -.01))
   bpy.context.view_layer.update()
   for side,shift in [('L',0),('R',math.pi)]:
    x=-.115 if side=='L' else .115;foot=Vector((x,0,.10))
    if mode in ['forward','back','left','right','sprint','crouchwalk']:
     stride=.41 if mode=='sprint' else (.22 if crouch else .34)
     travel,height=foot_cycle(phase+shift,stride,.12 if mode=='sprint' else .085)
     if side_yaw:
      foot=Quaternion((0,0,1),side_yaw)@foot;foot.x+=travel*(-1 if mode=='left' else 1)
     else:foot.y+=travel*(-1 if mode=='back' else 1)
     foot.z+=height
    elif mode=='jump':
     fold=math.sin(frame/frames*math.pi);foot.y-=.12*fold;foot.z+=.17*fold
    leg_ik(rig,side,offset,foot)
   if mode=='reload':
    reload_arm(rig,frame/frames)
   if mode=='death':
    t=frame/frames;collapse=t*t*(3-2*t)
    root=Matrix.Translation(Vector((0,.28*collapse,.88-.60*collapse)))@Quaternion((1,0,0),-1.40*collapse).to_matrix().to_4x4()@hips.bone.matrix_local.to_3x3().to_4x4()
    hips.matrix_basis=hips.bone.convert_local_to_pose(root,hips.bone.matrix_local,invert=True)
   for pb in rig.pose.bones:
    pb.keyframe_insert(data_path='location',frame=frame);pb.keyframe_insert(data_path='rotation_quaternion',frame=frame);pb.keyframe_insert(data_path='scale',frame=frame)
  for curve in action.fcurves:
   for key in curve.keyframe_points:key.interpolation='LINEAR'
  # glTF exporter collects compatible actions. Retain them without a running NLA stack.
  action.use_fake_user=True
 rig.animation_data.action=None
 for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
 scene.frame_set(0);scene.frame_start=0;scene.frame_end=60
 print('BIPED: 17 deforming bones, 11 keyframed clips')
