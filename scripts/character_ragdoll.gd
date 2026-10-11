class_name CharacterRagdoll
extends SkeletonModifier3D
# Cosmetic articulated corpse; authoritative hitboxes and respawn stay on Fighter.
const SEGMENTS={'Hips':'Chest','Chest':'Neck','Head':'','UpperArm.L':'Forearm.L','Forearm.L':'Hand.L','UpperArm.R':'Forearm.R','Forearm.R':'Hand.R','LeftUpLeg':'LeftLeg','LeftLeg':'LeftFoot','LeftFoot':'LeftToeBase','RightUpLeg':'RightLeg','RightLeg':'RightFoot','RightFoot':'RightToeBase'}
var bodies: Dictionary={}
var offsets: Dictionary={}
var world_root: Node3D
var running=false
func start(world: Node3D, momentum: Vector3, direction: Vector3, zone: String):
 if running:return
 var sk=get_skeleton()
 sk.force_update_all_bone_transforms()
 world_root=Node3D.new();world_root.name='CorpsePhysics';world.add_child(world_root)
 for name in SEGMENTS:
  var bone=sk.find_bone(name)
  if bone<0:continue
  var pose=sk.global_transform*sk.get_bone_global_pose(bone)
  var end=sk.find_bone(SEGMENTS[name])
  var tip=sk.global_transform*sk.get_bone_global_pose(end).origin if end>=0 else pose.origin+Vector3.UP*.18
  var span=tip-pose.origin
  if span.length()<.02:span=Vector3.UP*.12
  var radius=.055 if 'Arm' in name else (.075 if 'Leg' in name else .07)
  if name=='Hips':radius=.13
  if name=='Chest':radius=.16
  if name=='Head':radius=.105
  var y=span.normalized();var x=Vector3.RIGHT-y*Vector3.RIGHT.dot(y)
  if x.length()<.01:x=Vector3.FORWARD-y*Vector3.FORWARD.dot(y)
  x=x.normalized()
  var transform=Transform3D(Basis(x,y,x.cross(y).normalized()),(pose.origin+tip)*.5)
  var body=RigidBody3D.new();body.name=name.replace('.','_');body.mass=12.0 if name in ['Chest','Hips'] else (4.0 if 'UpLeg' in name else 2.0)
  body.collision_layer=16;body.collision_mask=1|8;body.linear_damp=.7;body.angular_damp=1.8;body.continuous_cd=true
  var material=PhysicsMaterial.new();material.friction=.85;material.bounce=0;body.physics_material_override=material
  world_root.add_child(body);body.global_transform=transform
  var shape=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=radius;capsule.height=maxf(span.length(),radius*2);shape.shape=capsule;body.add_child(shape)
  body.linear_velocity=momentum.limit_length(9)*.5
  bodies[bone]=body;offsets[bone]=transform.affine_inverse()*pose
 for bone in bodies:
  var parent=sk.get_bone_parent(bone)
  while parent>=0 and not bodies.has(parent):parent=sk.get_bone_parent(parent)
  if parent<0:continue
  var knee=sk.get_bone_name(bone) in ['LeftLeg','RightLeg']
  var joint
  if knee:
   joint=HingeJoint3D.new()
   joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT,true)
   joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER,-1.8)
   joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER,.08)
  else:
   joint=PinJoint3D.new()
   joint.set_param(PinJoint3D.PARAM_BIAS,.2)
   joint.set_param(PinJoint3D.PARAM_DAMPING,1.0)
  world_root.add_child(joint)
  var pose=sk.global_transform*sk.get_bone_global_pose(bone)
  var body: RigidBody3D=bodies[bone]
  var axis=body.global_basis.y;var up=Vector3.UP-axis*Vector3.UP.dot(axis)
  if up.length()<.01:up=Vector3.FORWARD-axis*Vector3.FORWARD.dot(axis)
  up=up.normalized();joint.global_transform=Transform3D(Basis(axis,up,axis.cross(up)),pose.origin)
  if knee:
   var z=body.global_basis.x;var x=z.cross(Vector3.UP).normalized()
   joint.global_transform=Transform3D(Basis(x,z.cross(x).normalized(),z),pose.origin)
  joint.node_a=joint.get_path_to(bodies[parent]);joint.node_b=joint.get_path_to(body)
 var chest=sk.find_bone('Chest');var head=sk.find_bone('Head')
 if bodies.has(chest):bodies[chest].apply_central_impulse(direction.limit_length(1)*5.0+Vector3.UP*.4)
 if zone=='HEAD' and bodies.has(head):bodies[head].apply_central_impulse(direction.limit_length(1)*1.2)
 running=true;active=true
func drop_weapon(gun: Node3D, momentum: Vector3, direction: Vector3):
 if not running or not is_instance_valid(gun):return
 var body=RigidBody3D.new();body.name='DroppedWeapon';body.mass=3.0
 body.collision_layer=16;body.collision_mask=1|8;body.linear_damp=.6;body.angular_damp=2.0;body.continuous_cd=true
 world_root.add_child(body);body.global_transform=Transform3D(gun.global_basis.orthonormalized(),gun.global_position)
 var copy=gun.duplicate();body.add_child(copy);copy.global_transform=gun.global_transform
 var bounds=AABB();var first=true
 var geometry_list=copy.find_children('*','MeshInstance3D',true,false)
 if copy is MeshInstance3D:geometry_list.push_front(copy)
 for geometry in geometry_list:
  if not geometry.visible:continue
  var local_bounds=(body.global_transform.affine_inverse()*geometry.global_transform)*geometry.get_aabb()
  bounds=local_bounds if first else bounds.merge(local_bounds);first=false
 if first:body.queue_free();return
 var shape=CollisionShape3D.new();var box=BoxShape3D.new()
 box.size=bounds.size.max(Vector3.ONE*.03);shape.shape=box;body.add_child(shape);shape.position=bounds.get_center()
 body.linear_velocity=momentum.limit_length(9)*.5+direction.limit_length(1)*.6
 body.angular_velocity=Vector3(1,.5,.3)
 gun.visible=false
func _process_modification():
 if not running:return
 var sk=get_skeleton();var inverse=sk.global_transform.affine_inverse()
 for bone in bodies:
  if is_instance_valid(bodies[bone]):sk.set_bone_global_pose(bone,inverse*bodies[bone].global_transform*offsets[bone])
func stop():
 running=false;active=false
 if is_instance_valid(world_root):world_root.queue_free()
 world_root=null;bodies.clear();offsets.clear()
func _exit_tree():stop()
