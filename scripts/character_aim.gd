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
 var pitch=clampf(actor.pitch*.85+recoil,-.7,.7)
 skeleton.set_bone_pose_rotation(index,Quaternion(axis,pitch)*skeleton.get_bone_pose_rotation(index))
