extends SceneTree
var g: Node3D
var directory=ProjectSettings.globalize_path('res://build/screenshots-v6')
func _initialize():call_deferred('run')
func shot(name: String):
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(directory+'/'+name+'.png');print('SCREENSHOT ',name)
func run():
 DirAccess.make_dir_recursive_absolute(directory)
 g=load('res://main.tscn').instantiate();root.add_child(g)
 await create_timer(.2).timeout;await shot('menu')
 g.showcase=true;g.start_match(false)
 for f in g.fighters:
  f.set_physics_process(false);f.set_process(false)
  if f.body_motion:f.body_motion.tree.active=false
 var p=g.player;p.position=Vector3(0,.1,-15);p.yaw=PI;p.pitch=0;p.velocity=Vector3.ZERO
 p.weapon_id=3;p.build_gun()
 for i in range(45):p._process(.016)
 await shot('pistol-ready')
 p.cooldown=0;p.shoot();p._process(.016);await shot('pistol-firing')
 p.cooldown=0;p.ammo[3]=1;p.shoot();p._process(.016);await shot('pistol-empty')
 p.start_reload();p.reload_left=Arsenal.WEAPONS[3].reload*.78*.7;p._process(.016);await shot('pistol-reload')
 p.reload_left=Arsenal.WEAPONS[3].reload*.78*.06;p._process(.016);await shot('pistol-release')
 p.reload_left=0;p.ammo[3]=12;p.weapon_id=0;p.build_gun()
 for i in range(45):p._process(.016)
 p.cooldown=0;p.shoot();p._process(.016);await shot('rifle-firing')
 g.hud.visible=false;g.menu_camera.position=Vector3(22,4,-22);g.menu_camera.look_at(Vector3(26,1.8,-12));g.menu_camera.current=true
 await shot('maintenance-access')
 quit()
