extends SkeletonModifier3D
var actor: Fighter
func _process_modification():
 if not actor or actor.dead:return
 var skeleton=get_skeleton();var index=skeleton.find_bone('Chest')
 if index<0:return
 var parent=skeleton.get_bone_parent(index)
 var basis=skeleton.get_bone_global_pose(parent).basis*skeleton.get_bone_rest(index).basis
 var axis=(basis.inverse()*Vector3.RIGHT).normalized()
 var recoil=maxf(0,actor.last_shot-.30)*.25
 var flinch=sin(PI*clampf(1.0-actor.hit_reaction/.22,0,1)) if actor.hit_reaction>0 else 0.0
 var incoming=actor.global_basis.inverse()*actor.last_hit_direction
 var pitch=clampf(actor.pitch*.85+recoil+incoming.z*flinch*.09,-.7,.7)
 var roll_axis=(basis.inverse()*Vector3.FORWARD).normalized()
 skeleton.set_bone_pose_rotation(index,Quaternion(roll_axis,incoming.x*flinch*.07)*Quaternion(axis,pitch)*skeleton.get_bone_pose_rotation(index))
 # Kick the actual weapon bone; GripIK follows its moving grip sockets.
 var weapon=skeleton.find_bone('Weapon')
 var age=.4-actor.last_shot
 if weapon>=0 and age>=0 and age<.10:
  var kick=sin(PI*age/.10)*.025
  var weapon_parent=skeleton.get_bone_parent(weapon)
  var local_dir=skeleton.global_basis.inverse()*(-actor.aim_dir())
  var offset=skeleton.get_bone_global_pose(weapon_parent).basis.inverse()*local_dir*kick
  skeleton.set_bone_pose_position(weapon,skeleton.get_bone_pose_position(weapon)+offset)
