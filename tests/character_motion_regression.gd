extends SceneTree
var checks=0
var failures=0
func expect(ok: bool, label: String):
 checks+=1
 print('PASS ' if ok else 'FAIL ',label)
 if not ok:failures+=1
func _initialize():call_deferred('run')
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(true)
 g.set_process(false);g.set_physics_process(false)
 for f in g.fighters:f.set_process(false);f.set_physics_process(false)
 var a=g.fighters[0];var motion=a.body_motion
 motion.graphical=true;motion.tree.active=true;motion.tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 var sk=motion.skeleton
 var service=motion.tree.tree_root.get_node('Service')
 var player=a.model.find_child('AnimationPlayer',true,false)
 var clip=player.get_animation(motion.clips.Reload)
 for name in ['UpperArm.R','Forearm.R','Hand.R','UpperArm.L','Forearm.L','Hand.L','Weapon']:
  var enabled=false
  for track in clip.get_track_count():
   var path=clip.track_get_path(track)
   if path.get_subname_count()>0 and String(path.get_subname(0))==name:enabled=service.is_path_filtered(path);break
  expect(enabled,'Actual reload graph includes '+name)
 expect(not CharacterMotion.reload_bone(sk,'LeftUpLeg') and not CharacterMotion.reload_bone(sk,'Chest'),'Reload leaves torso and legs on locomotion')
 var magazine=a.world_gun.find_child('MagazineRig',true,false)
 expect(magazine!=null and magazine.mesh.get_surface_count()>0,'ACR has an actual movable magazine mesh')
 var ik=a.model.find_child('GripIK',true,false)
 for t in [.125,.21,.30,.40,.55,.65,.80,1.0]:
  a.reload_left=a.reload_time(a.weapon_id)*(1-t)
  motion.reload_blend=1.0 if t<1 else 0.0
  motion.update(1.0/60);motion.tree.set('parameters/Air/blend_amount',0.0);motion.tree.advance(0)
  ik._process_modification()
  if t==.21 or t==.65:
   var wrist=sk.global_transform*sk.get_bone_global_pose(sk.find_bone('Hand.L')).origin
   expect(wrist.distance_to(a.world_gun.global_transform*ik.magazine_contact)<.005,'Hand reaches actual magazine well at '+str(t))
  if t==.30 or t==.55:
   var hand=sk.global_transform*sk.get_bone_global_pose(sk.find_bone('Hand.L')).origin
   var contact=magazine.global_transform*ik.magazine_contact
   expect(hand.distance_to(contact)<.001,'Carried magazine stays in actual hand at '+str(t))
  if t==.40:expect(not magazine.visible,'Magazine is stowed while hand fetches replacement')
  if t==.80:expect(magazine.visible and magazine.position.length()<.0001,'Replacement seats before hand returns to foregrip')
  if t==1.0:expect(magazine.visible and magazine.position==Vector3.ZERO,'Reload completion restores assembled weapon')
 a.reload_left=0;motion.reset();motion.update(1.0/60)
 expect(ik.reload_progress<0,'Respawn clears magazine handling')
 a.velocity=Vector3(0,0,-7.8);a.sprinting=true
 motion.update(1.0/60)
 expect(motion.sprint_blend>0 and motion.sprint_blend<.3,'Sprint pose eases in')
 for i in 45:motion.update(1.0/60)
 expect(motion.sprint_blend>.99,'Sprint reaches its authored stance')
 a.sprinting=false
 motion.update(1.0/60)
 expect(motion.sprint_blend>.7 and motion.sprint_blend<.9,'Sprint exit eases rather than snapping')
 for i in 45:motion.update(1.0/60)
 expect(motion.sprint_blend<.001,'Running without sprint does not select lowered weapon')
 motion.reload_blend=1;motion.air_blend=1;motion.crouch_blend=1;motion.reset()
 expect(motion.reload_blend==0 and motion.air_blend==0 and motion.crouch_blend==0 and motion.sprint_blend==0,'Respawn clears presentation state')
 g.queue_free();g=null;motion=null;a=null;sk=null;player=null;await process_frame;await process_frame
 print('CHARACTER_MOTION ',checks,' checks, ',failures,' failures');quit(0 if failures==0 else 1)
