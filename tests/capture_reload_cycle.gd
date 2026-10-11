extends SceneTree
func _initialize():call_deferred('run')
func run():
 var tag='before';var kind=0
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--tag='):tag=arg.substr(6)
  if arg.begins_with('--weapon='):kind=int(arg.substr(9))
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(false)
 g.set_process(false);g.set_physics_process(false);g.hud.visible=false
 for f in g.fighters:f.set_process(false);f.set_physics_process(false);f.model.visible=false
 var p=g.player;p.global_position=Vector3(-4,.18,-30);p.yaw=PI-.35;p.rotation.y=p.yaw;p.pitch=-.04;p.camera.rotation=Vector3(p.pitch,0,0)
 p.weapon_id=kind;p.build_gun();var rig=p.view
 print('CLIPS ',kind,' ',rig.clips)
 rig.player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 var path=ProjectSettings.globalize_path('res://build/reload-review');DirAccess.make_dir_recursive_absolute(path)
 for empty in [false,true]:
  p.ammo[kind]=0 if empty else 8
  for progress in [.2,.55,.85]:
   p.reload_left=p.reload_time(kind)*(1-progress);rig.update(p,0)
   rig.player.advance(.08)
   rig.player.seek(progress*rig.player.get_animation(rig.clips[rig.action]).length,true);rig.update(p,0)
   for i in 3:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(path+'/%s-w%d-%s-%d.png'%[tag,kind,'empty' if empty else 'tactical',int(progress*100)])
   print('RELOAD ',kind,' ',empty,' ',progress)
 g.queue_free();g=null;p=null;rig=null;await process_frame;await process_frame;quit()
