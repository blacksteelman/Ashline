extends SceneTree
func _initialize():call_deferred('run')
func capture(label:String):
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://build/reload-review/'+label+'.png'))
 print('ACTION_FRAME ',label)
func run():
 var kind=0
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--weapon='):kind=int(arg.substr(9))
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(false)
 g.set_process(false);g.set_physics_process(false);g.hud.visible=false
 for f in g.fighters:f.set_process(false);f.set_physics_process(false);f.model.visible=false
 var p=g.player;p.global_position=Vector3(-4,.18,-30);p.yaw=PI-.35;p.rotation.y=p.yaw;p.pitch=-.04
 p.weapon_id=kind;p.build_gun();p.view.stop_action();p.ads=true
 for i in 35:p._process(1.0/60)
 await capture('ads-w%d-idle'%kind)
 p.ammo[kind]=Arsenal.WEAPONS[kind].mag
 for n in 3:
  p.cooldown=0;p.shoot()
  p._process(.025)
  await capture('ads-w%d-shot%d'%[kind,n])
  g.clear_combat_effects()
  p._process(.045)
 p._process(.25);await capture('ads-w%d-recover'%kind)
 g.queue_free();g=null;p=null;await process_frame;await process_frame;quit()
