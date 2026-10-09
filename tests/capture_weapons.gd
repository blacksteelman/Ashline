extends SceneTree
# First-person weapon review frames: idle, ADS, firing and mid-reload per weapon.
var g: Node3D
var directory=ProjectSettings.globalize_path('res://build/screenshots-v8')
func _initialize():call_deferred('run')
func frames(n: int):
 for i in range(n):await process_frame
func shot(name: String):
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(directory+'/'+name+'.png');print('SCREENSHOT ',name)
func run():
 DirAccess.make_dir_recursive_absolute(directory)
 var only=[];var ads_only=false
 for a in OS.get_cmdline_user_args():
  if a.begins_with('--weapons='):only=Array(a.substr(10).split(',')).map(func(x):return int(x))
  if a=='--ads-only':ads_only=true
 g=load('res://main.tscn').instantiate();root.add_child(g);g.showcase=true;g.start_match(false)
 for f in g.fighters:
  if not f.local_player:f.set_physics_process(false);f.position=Vector3(0,-30,0)
 var p=g.player;p.set_physics_process(false)
 p.global_position=Vector3(-4.0,.05,-30.0);p.yaw=PI-.35;p.pitch=-.04;p.velocity=Vector3.ZERO
 g.hud.visible=false
 await frames(40)
 for w in [0,1,2,3]:
  if not only.is_empty() and w not in only:continue
  if w==3:p.weapon_id=3
  else:p.load_class(w)
  p.build_gun();p.view.equip_blend=1.0;p.ads=false;p.reload_left=0
  if not ads_only:await frames(25);await shot('vm%d-idle' % w)
  p.ads=true;await frames(30);await shot('vm%d-ads' % w);p.ads=false;await frames(25)
  if ads_only:continue
  p.cooldown=0;p.ammo[w]=10;p.shoot();await frames(1);await shot('vm%d-fire' % w);await frames(20)
  p.ammo[w]=5;p.start_reload();var total=p.reload_left;p.reload_left=total*.45;await frames(2);await shot('vm%d-reload' % w);p.reload_left=0
 quit()
