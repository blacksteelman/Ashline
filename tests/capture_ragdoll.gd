extends SceneTree
func _initialize():call_deferred('run')
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(false)
 g.set_process(false);g.set_physics_process(false);g.hud.visible=false
 for f in g.fighters:f.set_process(false);f.set_physics_process(false);f.model.visible=false
 g.player.gun.visible=false
 var a=g.fighters[1];a.model.visible=true;a.global_position=Vector3(1.5,.18,-30);a.rotation.y=0
 var motion=a.body_motion;motion.tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 g.menu_camera.current=true;g.menu_camera.fov=45
 g.menu_camera.global_position=a.global_position+Vector3(2.1,1.45,-3.2)
 g.menu_camera.look_at(a.global_position+Vector3(0,.8,0))
 var path=ProjectSettings.globalize_path('res://build/ragdoll-review')
 DirAccess.make_dir_recursive_absolute(path)
 for i in 35:motion.update(1.0/60);motion.tree.set('parameters/Air/blend_amount',0.0);motion.tree.advance(1.0/60)
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path+'/alive.png')
 a.cooldown=0;a.yaw=0;a.shoot();a.last_shot=.375
 motion.tree.advance(1.0/60)
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path+'/firing.png')
 g.clear_combat_effects();a.last_shot=0
 a.hurt(8,g.fighters[0],'TORSO');a.hit_reaction=.11;motion.tree.advance(1.0/60)
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path+'/hit.png')
 a.hurt(200,g.fighters[0],'HEAD');motion.update(1.0/60)
 for stage in ['fall','settled']:
  for i in (12 if stage=='fall' else 100):await physics_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(path+'/'+stage+'.png')
  print('CORPSE ',stage)
  for bone in motion.ragdoll.bodies:
   print(motion.skeleton.get_bone_name(bone),' body=',motion.ragdoll.bodies[bone].global_position,' bone=',motion.skeleton.global_transform*motion.skeleton.get_bone_global_pose(bone).origin)
  if stage=='settled':
   g.menu_camera.global_position=a.global_position+Vector3(0,4,1)
   g.menu_camera.look_at(a.global_position+Vector3(0,0,0))
   for i in 3:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(path+'/overhead.png')
 a.spawn();a.global_position=Vector3(1.5,.18,-30)
 g.menu_camera.global_position=a.global_position+Vector3(2.1,1.45,-3.2)
 g.menu_camera.look_at(a.global_position+Vector3(0,.8,0))
 for i in 35:motion.update(1.0/60);motion.tree.set('parameters/Air/blend_amount',0.0);motion.tree.advance(1.0/60)
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path+'/respawn.png')
 g.queue_free();g=null;await process_frame;await process_frame;quit()
