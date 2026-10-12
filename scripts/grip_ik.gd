class_name GripIK
extends SkeletonModifier3D
# Locks wrists to each weapon's grip/support near the authored holding pose.
# Blend the lock away during magazine handling so the reload clip keeps its path.
# Two-bone solves preserve the animated elbow plane; calibrated wrist frames
# align the palms with each weapon without replacing free reload motion.

# Authored wrist points in socket space (build_soldiers.py GRIP / SUPPORT: weapon (x,y,z) -> socket (x,z,-y)).
const AUTHORED_GRIP=Vector3(0.04,-0.07,0.04)
const AUTHORED_SUPPORT=Vector3(-0.06,-0.07,-0.27)
static var measure=false
const MAX_REACH=-0.27
var socket: Node3D
var grip=AUTHORED_GRIP
var support=AUTHORED_SUPPORT
var weapon_bone=-1
var arms={}
var hand_frames={}
var hold_frames={}
var magazine_hand_frame=Basis.IDENTITY
var magazine: MeshInstance3D
var reload_progress=-1.0
var magazine_contact=Vector3.ZERO

static func service_contact_weight(t: float) -> float:
 if t<0:return 0.0
 return smoothstep(0,.125,t)*(1.0-smoothstep(.21,.375,t))+smoothstep(.475,.65,t)*(1.0-smoothstep(.725,.89,t))

static func attach(holder: Node3D, socket_node: Node3D, weapon: Node3D) -> GripIK:
 var sk: Skeleton3D=holder.find_child('Skeleton3D',true,false)
 if not sk or not socket_node:return null
 var ik: GripIK=sk.get_node_or_null('GripIK')
 if not ik:ik=GripIK.new();ik.name='GripIK';sk.add_child(ik)
 ik.socket=socket_node;ik.weapon_bone=sk.find_bone('Weapon')
 ik.magazine=weapon.find_child('MagazineRig',true,false) as MeshInstance3D if weapon else null
 ik.reload_progress=-1.0
 if ik.magazine:
  var bounds=ik.magazine.get_aabb()
  # Place the wrist behind the near magazine edge, leaving room for the palm.
  # A center-based wrist target pushed the rifle magazines beyond arm reach.
  ik.magazine_contact=Vector3(bounds.position.x-.035,bounds.get_center().y-.02,bounds.end.z+.035)
 ik.grip=weapon.get_meta('grip',AUTHORED_GRIP) if weapon else AUTHORED_GRIP
 ik.support=weapon.get_meta('support',AUTHORED_SUPPORT) if weapon else AUTHORED_SUPPORT
 # The first-person hands reach further forward than this stance allows (ACR handguard ~0.40 m): cap it.
 ik.support.z=maxf(ik.support.z,MAX_REACH)
 # ...and keep the wrist just under the bore (the sniper's first-person hand sits low under a tall stock).
 if weapon and weapon.has_meta('muzzle'):ik.support.y=maxf(ik.support.y,weapon.get_meta('muzzle').y-.06)
 ik.hand_frames.clear();ik.hold_frames.clear()
 for side in ['R','L']:
  ik.arms[side]=[sk.find_bone('UpperArm.'+side),sk.find_bone('Forearm.'+side),sk.find_bone('Hand.'+side)]
  var hand=sk.find_bone('Hand.'+side)
  var finger=sk.find_bone(('Right' if side=='R' else 'Left')+'HandFinger1')
  var thumb=sk.find_bone(side+'Thumb')
  if hand<0 or finger<0 or thumb<0:continue
  var rest=sk.get_bone_global_rest(hand)
  var f=rest.basis.inverse()*(sk.get_bone_global_rest(finger).origin-rest.origin)
  var t=rest.basis.inverse()*(sk.get_bone_global_rest(thumb).origin-rest.origin)
  ik.hand_frames[side]=contact_frame(f,t)
  var prefix='grip' if side=='R' else 'support'
  if weapon and weapon.has_meta(prefix+'_fingers') and weapon.has_meta(prefix+'_thumb'):
   ik.hold_frames[side]=contact_frame(weapon.get_meta(prefix+'_fingers'),weapon.get_meta(prefix+'_thumb'))*ik.hand_frames[side].inverse()
 if ik.hand_frames.has('L') and ik.magazine:
  # Fingers reach from the wrist into the magazine; the thumb runs up its side.
  # Reusing the rifle support frame points fingers away from a detached magazine.
  var f=(ik.magazine.get_aabb().get_center()-ik.magazine_contact).normalized()
  ik.magazine_hand_frame=contact_frame(f,Vector3.UP)*ik.hand_frames.L.inverse()
 return ik

static func contact_frame(fingers: Vector3, thumb: Vector3) -> Basis:
 var f=fingers.normalized()
 var t=(thumb-f*thumb.dot(f)).normalized()
 return Basis(f,t,f.cross(t)).orthonormalized()

func _process_modification():
 var sk=get_skeleton()
 if not sk or weapon_bone<0 or not is_instance_valid(socket) or not socket.is_inside_tree():return
 var to_socket=sk.global_transform.affine_inverse()*socket.global_transform  # socket space -> skeleton space
 for side in ['R','L']:
  var b=arms.get(side,[-1,-1,-1])
  if b[0]<0 or b[1]<0 or b[2]<0:continue
  var wrist=sk.get_bone_global_pose(b[2]).origin
  var intended=to_socket.affine_inverse()*wrist
  if measure:print('GRIPIK ',side,' intended ',intended)
  var authored=AUTHORED_GRIP if side=='R' else AUTHORED_SUPPORT
  var lock=1.0-smoothstep(.06,.16,intended.distance_to(authored))
  var target=intended.lerp(grip if side=='R' else support,lock)
  var service_weight=service_contact_weight(reload_progress) if side=='L' else 0.0
  if side=='L' and is_instance_valid(magazine) and reload_progress>=0:
   target=target.lerp(magazine_contact,service_contact_weight(reload_progress))
  solve(sk,b,to_socket*target)
  var pose=sk.get_bone_global_pose(b[2])
  var rotation=pose.basis.orthonormalized().get_rotation_quaternion()
  if hold_frames.has(side):
   var desired=(to_socket.basis.orthonormalized()*hold_frames[side]).get_rotation_quaternion()
   rotation=rotation.slerp(desired,lock*(1.0-service_weight))
  if side=='L' and hand_frames.has('L') and service_weight>0:
   var desired=(to_socket.basis.orthonormalized()*magazine_hand_frame).get_rotation_quaternion()
   rotation=rotation.slerp(desired,service_weight)
  pose.basis=Basis(rotation).scaled(pose.basis.get_scale())
  sk.set_bone_global_pose(b[2],pose)
 if is_instance_valid(magazine):
  var t=reload_progress
  magazine.visible=not (t>=.375 and t<.475)
  magazine.transform=Transform3D.IDENTITY
  if t>=.21 and t<.65 and arms.has('L'):
   # Evaluate after the arm solve: the carried magazine follows the actual wrist,
   # including the animation's weapon tilt and the chest aim modifier.
   var hand=to_socket.affine_inverse()*sk.get_bone_global_pose(arms.L[2])
   var rotation=hand.basis.orthonormalized()*magazine_hand_frame.inverse() if hand_frames.has('L') else Basis.IDENTITY
   magazine.transform=Transform3D(rotation,hand.origin-rotation*magazine_contact)

func solve(sk: Skeleton3D, b: Array, target: Vector3):
 var upper=sk.get_bone_global_pose(b[0]);var fore=sk.get_bone_global_pose(b[1]);var hand=sk.get_bone_global_pose(b[2])
 var s=upper.origin;var e=fore.origin;var w=hand.origin
 var a=s.distance_to(e);var c=e.distance_to(w)
 var to=target-s
 if to.length()<.001 or a<.001 or c<.001:return
 var dist=clampf(to.length(),absf(a-c)*1.02,(a+c)*.999)
 var u=to.normalized()
 # Bend direction: the clip's elbow offset from the shoulder-target line.
 var v=(e-s)-u*(e-s).dot(u)
 if v.length()<.0001:v=(w-s).cross(u).cross(u)
 v=v.normalized()
 var cos_a=clampf((a*a+dist*dist-c*c)/(2*a*dist),-1,1)
 var elbow=s+u*a*cos_a+v*a*sqrt(1-cos_a*cos_a)
 var wrist=s+u*dist
 var r1=Quaternion((e-s).normalized(),(elbow-s).normalized())
 upper.basis=Basis(r1)*upper.basis
 var w_rot=s+Basis(r1)*(w-s)
 var r2=Quaternion((w_rot-elbow).normalized(),(wrist-elbow).normalized())
 fore=Transform3D(Basis(r2)*Basis(r1)*fore.basis,elbow)
 sk.set_bone_global_pose(b[0],upper)
 sk.set_bone_global_pose(b[1],fore)
 sk.set_bone_global_pose(b[2],Transform3D(hand.basis,wrist))
