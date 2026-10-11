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

static func attach(holder: Node3D, socket_node: Node3D, weapon: Node3D) -> GripIK:
 var sk: Skeleton3D=holder.find_child('Skeleton3D',true,false)
 if not sk or not socket_node:return null
 var ik: GripIK=sk.get_node_or_null('GripIK')
 if not ik:ik=GripIK.new();ik.name='GripIK';sk.add_child(ik)
 ik.socket=socket_node;ik.weapon_bone=sk.find_bone('Weapon')
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
  solve(sk,b,to_socket*target)

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
