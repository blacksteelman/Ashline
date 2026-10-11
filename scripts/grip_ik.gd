class_name GripIK
extends SkeletonModifier3D
# Locks wrists to each weapon's grip/support near the authored holding pose.
# Blend the lock away during magazine handling so the reload clip keeps its path.
# Two-bone solves preserve the animated elbow plane and hand rotation.

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
  # Wrist beside the actual magazine, with fingers wrapped around its middle.
  ik.magazine_contact=bounds.get_center()+Vector3(-.05,-.025,0)
 ik.grip=weapon.get_meta('grip',AUTHORED_GRIP) if weapon else AUTHORED_GRIP
 ik.support=weapon.get_meta('support',AUTHORED_SUPPORT) if weapon else AUTHORED_SUPPORT
 # The first-person hands reach further forward than this stance allows (ACR handguard ~0.40 m): cap it.
 ik.support.z=maxf(ik.support.z,MAX_REACH)
 # ...and keep the wrist just under the bore (the sniper's first-person hand sits low under a tall stock).
 if weapon and weapon.has_meta('muzzle'):ik.support.y=maxf(ik.support.y,weapon.get_meta('muzzle').y-.06)
 for side in ['R','L']:
  ik.arms[side]=[sk.find_bone('UpperArm.'+side),sk.find_bone('Forearm.'+side),sk.find_bone('Hand.'+side)]
 return ik

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
  var target: Vector3
  if side=='R':target=intended.lerp(grip,1.0-smoothstep(.06,.16,intended.distance_to(AUTHORED_GRIP)))
  else:target=intended.lerp(support,1.0-smoothstep(.06,.16,intended.distance_to(AUTHORED_SUPPORT)))
  if side=='L' and is_instance_valid(magazine) and reload_progress>=0:
   target=target.lerp(magazine_contact,service_contact_weight(reload_progress))
  solve(sk,b,to_socket*target)
 if is_instance_valid(magazine):
  var t=reload_progress
  magazine.visible=not (t>=.375 and t<.475)
  magazine.position=Vector3.ZERO
  if t>=.21 and t<.65 and arms.has('L'):
   # Evaluate after the arm solve: the carried magazine follows the actual wrist,
   # including the animation's weapon tilt and the chest aim modifier.
   var hand=sk.get_bone_global_pose(arms.L[2]).origin
   magazine.position=to_socket.affine_inverse()*hand-magazine_contact

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
