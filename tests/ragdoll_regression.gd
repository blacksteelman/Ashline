extends SceneTree
var checks=0
var failures=0
func expect(ok: bool,label:String):
 checks+=1;print('PASS ' if ok else 'FAIL ',label)
 if not ok:failures+=1
func _initialize():call_deferred('run')
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(false)
 g.set_process(false);g.set_physics_process(false)
 for f in g.fighters:f.set_process(false);f.set_physics_process(false)
 var a=g.fighters[1];a.global_position=Vector3(1.5,.18,-30);a.velocity=Vector3.ZERO
 var motion=a.body_motion;motion.graphical=true
 motion.tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 for i in 35:motion.update(1.0/60);motion.tree.set('parameters/Air/blend_amount',0.0);motion.tree.advance(1.0/60)
 await physics_frame;await physics_frame
 a.hurt(12,g.fighters[0],'TORSO')
 expect(a.hit_reaction>0 and a.last_hit_zone=='TORSO','Nonlethal hit starts a directional skeletal reaction')
 expect(a.last_hit_direction.dot((a.global_position-g.fighters[0].global_position).normalized())>.99,'Reaction records actual incoming shot direction')
 a.hurt(200,g.fighters[0],'HEAD');motion.update(1.0/60)
 var rag=motion.ragdoll
 expect(rag.running and rag.active,'Death activates physical skeleton')
 expect(rag.bodies.size()==13,'Corpse has thirteen articulated rigid bodies')
 expect(rag.world_root.get_child_count()==26,'Twelve joints connect the body beside dropped weapon')
 expect(not motion.tree.active and not a.model.find_child('GripIK',true,false).active,'Death disables animation and hand constraints')
 expect(rag.world_root.get_node_or_null('DroppedWeapon') is RigidBody3D and not a.world_gun.visible,'Death releases the actual gun into physics')
 var chest=motion.skeleton.find_bone('Chest');var initial=rag.bodies[chest].global_position
 for i in 600:await physics_frame
 var moved=rag.bodies[chest].global_position
 print('RAGDOLL chest ',initial,' -> ',moved)
 expect(initial.distance_to(moved)>.15,'Corpse actually falls under physics')
 var stable=true
 for bone in rag.bodies:
  var body=rag.bodies[bone]
  if not body.global_position.is_finite() or body.global_position.distance_to(initial)>4 or body.global_position.y<-.2:stable=false
 expect(stable,'Body remains finite, near death position and above floor')
 rag._process_modification()
 var pose=motion.skeleton.global_transform*motion.skeleton.get_bone_global_pose(chest)
 expect(pose.origin.distance_to((rag.bodies[chest].global_transform*rag.offsets[chest]).origin)<.01,'Visible skeleton follows simulated chest')
 var corpse=rag.world_root
 a.spawn();await process_frame;await process_frame
 expect(not is_instance_valid(corpse) and not rag.running and rag.bodies.is_empty(),'Respawn removes corpse physics')
 motion.update(1.0/60)
 expect(motion.tree.active and a.model.find_child('GripIK',true,false).active,'Respawn restores animation and grip')
 # The receiver and the magazine in the hand must become independent bodies
 # when death interrupts a reload; a seated magazine stays inside the gun.
 for kind in [1,2,3,4]:
  a.weapon_id=kind;a.update_world_weapon();a.reload_left=a.reload_time(kind)*.7
  motion.reload_blend=1;motion.update(1.0/60);motion.tree.set('parameters/Air/blend_amount',0.0);motion.tree.advance(0)
  var ik=a.model.find_child('GripIK',true,false);ik._process_modification()
  a.dead=true;motion.update(1.0/60)
  var loose=rag.world_root.get_node_or_null('DroppedMagazine')
  var gun_body=rag.world_root.get_node_or_null('DroppedWeapon')
  expect(loose is RigidBody3D and loose.mass<1.0,'Weapon '+str(kind)+' releases the carried magazine independently')
  expect(gun_body.find_child('MagazineRig',true,false)==null and loose.find_child('MagazineRig',true,false)!=null,'Weapon '+str(kind)+' dropped receiver does not retain a floating magazine')
  var loose_ref=loose
  a.spawn();await process_frame;await process_frame
  expect(not is_instance_valid(loose_ref),'Weapon '+str(kind)+' respawn cleans loose magazine physics')
 var p=g.player;p.body_motion.graphical=true
 p.hurt(200,g.fighters[6],'TORSO');p._process(1.0/60)
 expect(p.body_motion.ragdoll.running and p.camera.global_position.distance_to(p.eye())>.05,'Local death camera follows the physical corpse')
 p.spawn()
 expect(p.camera.position.distance_to(Vector3(0,1.62,0))<.001 and not p.body_motion.ragdoll.running,'Respawn restores first-person camera')
 p.hurt(1,g.fighters[6],'TORSO')
 expect(g.damage_direction_time>0 and g.damage_origin==g.fighters[6].eye(),'Incoming damage records attacker position for HUD')
 a.hurt(200,g.fighters[6],'TORSO');motion.update(1.0/60)
 var remote_corpse=rag.world_root
 var data=[]
 for f in g.fighters:
  data.append([f.position,f.yaw,f.pitch,f.health,f.dead,f.kills,f.deaths,f.streak,f.ammo,f.reserves,f.weapon_id,f.respawn_time,f.rewards,f.class_id,f.reload_left,f.crouched,f.acknowledged_fire,[f.loadout.primary,f.loadout.perks]])
 data[1][4]=false;data[1][3]=100.0
 g.snapshot(var_to_bytes(data).compress(FileAccess.COMPRESSION_DEFLATE),g.scores,g.time_left,g.radar_time,1.0)
 await process_frame;await process_frame
 expect(not rag.running and not is_instance_valid(remote_corpse),'Network respawn also removes cosmetic corpse')
 expect(a.model.find_child('GripIK',true,false).active,'Network respawn restores hand constraints')
 p=null
 g.queue_free();g=null;a=null;motion=null;rag=null;await process_frame;await process_frame
 print('RAGDOLL ',checks,' checks, ',failures,' failures');quit(0 if failures==0 else 1)
