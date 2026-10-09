extends SkeletonModifier3D
# Adds the per-shot bolt / slide stroke and the empty lock-back on top of the baked pose.
var rig
var lock=0.0
func _process_modification():
 if not rig:return
 var skeleton=get_skeleton();var index=skeleton.find_bone('bolt')
 if index<0:return
 var travel=maxf(rig.kick_bolt,lock)*.045
 var pose=skeleton.get_bone_pose_position(index)
 skeleton.set_bone_pose_position(index,pose+Vector3(0,-travel,0))
