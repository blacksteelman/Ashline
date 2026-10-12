extends SceneTree
# Actual Fighter + CharacterMotion + GripIK in the map, deterministic animation evaluation.
func _initialize():call_deferred('run')
func frames(n):
 for i in n:await process_frame
func run():
 var tag='before'
 for a in OS.get_cmdline_user_args():
  if a.begins_with('--tag='):tag=a.substr(6)
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(false)
 g.set_process(false);g.set_physics_process(false);g.hud.visible=false
 for f in g.fighters:f.set_process(false);f.set_physics_process(false);f.model.visible=false
 g.player.gun.visible=false
 var a=g.fighters[1];a.model.visible=true;a.global_position=Vector3(1.5,.18,-30);a.rotation.y=0
 var motion=a.body_motion;motion.tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 g.menu_camera.current=true;g.menu_camera.fov=45
 g.menu_camera.global_position=a.global_position+Vector3(.8,1.48,-1.05)
 g.menu_camera.look_at(a.global_position+Vector3(0,1.32,-.18))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path('res://build/hand-review/'+tag))
 for kind in [0,1,2,3,4]:
  a.weapon_id=kind;a.update_world_weapon()
  for progress in [0.0,.30,.65]:
   a.velocity=Vector3.ZERO;a.sprinting=false;a.pitch=0
   a.reload_left=a.reload_time(kind)*(1-progress) if progress>0 else 0.0
   motion.reset()
   for i in 35:
    motion.update(1.0/60);motion.tree.set('parameters/Air/blend_amount',0.0);motion.tree.advance(1.0/60)
   await frames(2)
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://build/hand-review/'+tag+'/magazine-w%d-%d.png'%[kind,int(progress*100)]))
   print('MAGAZINE ',kind,' ',progress)
 g.queue_free();g=null;await frames(2);quit()
