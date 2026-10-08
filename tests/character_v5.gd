extends SceneTree
var passed=0
var failed=0
func _initialize():call_deferred('run')
func check(ok: bool,message: String):
 if ok:passed+=1;print('PASS: ',message)
 else:failed+=1;push_error('FAIL: '+message)
func pose(motion: CharacterMotion, name: String,time: float):
 var player=motion.tree.get_node(motion.tree.anim_player) as AnimationPlayer
 motion.tree.active=false;player.play(motion.clips[name]);player.seek(time,true);player.pause();motion.skeleton.force_update_all_bone_transforms()
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(false)
 for f in g.fighters:f.set_physics_process(false);f.set_process(false)
 var f=g.fighters[6];var m=f.body_motion
 check(m!=null,'Soldier uses skeletal presentation')
 if not m:quit(1);return
 check(m.skeleton.get_bone_count()==17,'Seventeen body bones survive GLB export')
 check(m.clips.size()==11,'Movement, crouch, air, reload and death clips survive export')
 var deforms=false
 for mesh in m.skeleton.get_parent().find_children('*','MeshInstance3D',true,false):
  if mesh.skin and mesh.skeleton==mesh.get_path_to(m.skeleton):deforms=true
 check(deforms,'Soldier meshes reference the body skeleton and skin binds')
 check(f.model.get_node_or_null('LegL')==null,'Transform-only leg pivots are removed')
 check(f.world_gun.get_parent()==m.anchor and m.anchor.bone_name=='Chest','Weapon follows the chest bone')
 pose(m,'Idle',.3)
 var head=m.skeleton.get_bone_global_pose(m.skeleton.find_bone('Head')).origin
 var head_basis=m.skeleton.get_bone_global_pose(m.skeleton.find_bone('Head')).basis
 pose(m,'CrouchIdle',.3)
 var crouch_head=m.skeleton.get_bone_global_pose(m.skeleton.find_bone('Head')).origin
 var foot=m.skeleton.get_bone_global_pose(m.skeleton.find_bone('Foot.L')).origin
 check(head.y-crouch_head.y>.50 and head.y-crouch_head.y<.60,'Crouch changes skeleton height without translating the whole model')
 check(absf(foot.y-.10)<.015,'Crouched foot remains on its ground contact height')
 pose(m,'Forward',.2)
 var swing=m.skeleton.get_bone_global_pose(m.skeleton.find_bone('Foot.L')).origin
 var stance=m.skeleton.get_bone_global_pose(m.skeleton.find_bone('Foot.R')).origin
 check(swing.y>stance.y+.04 and absf(stance.y-.10)<.015,'Walking lifts swing foot while keeping stance foot planted')
 pose(m,'Forward',.5)
 var planted=m.skeleton.to_global(m.skeleton.get_bone_global_pose(m.skeleton.find_bone('Foot.L')).origin)
 f.global_position+=Vector3(0,0,-.17).rotated(Vector3.UP,f.rotation.y)
 pose(m,'Forward',.6)
 check(planted.distance_to(m.skeleton.to_global(m.skeleton.get_bone_global_pose(m.skeleton.find_bone('Foot.L')).origin))<.02,'Stance foot stays at the same world position during matched root movement')
 pose(m,'Reload',.5)
 var hand=m.skeleton.get_bone_global_pose(m.skeleton.find_bone('Hand.L')).origin
 check(hand.distance_to(Vector3(.088,1.03,-.37))<.06,'Reload hand approaches the magazine contact position')
 pose(m,'Death',.999)
 check(m.skeleton.get_bone_global_pose(m.skeleton.find_bone('Head')).origin.y<.50,'Death clip collapses the skeleton toward the ground')
 pose(m,'Left',.2)
 check(head_basis.get_rotation_quaternion().angle_to(m.skeleton.get_bone_global_pose(m.skeleton.find_bone('Head')).basis.get_rotation_quaternion())<.08,'Strafing turns hips while keeping the upper body facing its target')
 m.tree.active=true;m.tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 m.tree.set('parameters/Movement/blend_position',Vector2(0,-1));m.tree.set('parameters/Cadence/scale',1.0)
 for name in ['Fast','Low','Air','Down','Service']:m.tree.set('parameters/'+name+'/blend_amount',0.0)
 m.tree.advance(.2);m.skeleton.force_update_all_bone_transforms()
 var walking_foot=m.skeleton.get_bone_global_pose(m.skeleton.find_bone('Foot.L')).origin
 m.tree.set('parameters/Service/blend_amount',1.0);m.tree.set('parameters/ReloadClock/seek_request',.5);m.tree.advance(0);m.skeleton.force_update_all_bone_transforms()
 check(walking_foot.distance_to(m.skeleton.get_bone_global_pose(m.skeleton.find_bone('Foot.L')).origin)<.01,'Reload overlay preserves the moving lower body')
 check(m.skeleton.get_bone_global_pose(m.skeleton.find_bone('Hand.L')).origin.z>-.43,'Reload overlay actually applies to the support arm')
 f.update_world_weapon();f.update_world_weapon()
 check(f.model.find_children('WorldWeapon','Node3D',true,false).size()==1,'Weapon replacement retains one attached world weapon')
 g.set_process(false);g.set_physics_process(false);g.net_mode='client'
 g.shot_event(6,f.eye(),f.aim_dir())
 check(f.last_shot>.35,'Remote shot creates a transient radar/recoil indication')
 f._process(.5)
 check(f.last_shot==0,'Remote firing indication expires between snapshots')
 var report={'passed':passed,'failed':failed,'success':failed==0}
 var out=FileAccess.open('res://tests/character_v5_report.json',FileAccess.WRITE);out.store_string(JSON.stringify(report,'  '))
 print('CHARACTER_V5 ',JSON.stringify(report));quit(1 if failed else 0)
