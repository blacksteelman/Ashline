extends SceneTree
var g: Node3D
var directory=ProjectSettings.globalize_path('res://build/screenshots-v7')
func _initialize():call_deferred('run')
func shot(name: String):
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(directory+'/'+name+'.png');print('SCREENSHOT ',name)
func run():
 DirAccess.make_dir_recursive_absolute(directory)
 g=load('res://main.tscn').instantiate();root.add_child(g);g.showcase=true;g.start_match(false)
 for f in g.fighters:
  f.set_physics_process(false);f.set_process(false)
  if f.body_motion:f.body_motion.tree.active=false
 var p=g.player;p.position=Vector3(0,.1,-15);p.yaw=PI;p.pitch=0;p.velocity=Vector3.ZERO
 for i in range(45):p._process(.016)
 await shot('rifle-ready')
 p.ads=true
 for i in range(45):p._process(.016)
 await shot('rifle-ads')
 p.ads=false
 for i in range(45):p._process(.016)
 p.cooldown=0;p.shoot();p._process(.016);await shot('rifle-firing')
 p.ammo[0]=13;p.start_reload();p.reload_left=Arsenal.WEAPONS[0].reload*.78*.55
 for i in range(25):p._process(.016)
 await shot('rifle-reload')
 p.reload_left=0;p.ammo[0]=30
 p.position=Vector3(1,.1,-7);p.yaw=PI/2;p.pitch=0
 for i in range(45):p._process(.016)
 await shot('workshop-approach')
 g.hud.visible=false;g.menu_camera.position=Vector3(-8,1.65,-11);g.menu_camera.look_at(Vector3(-13,1.5,-15));g.menu_camera.current=true
 await shot('workshop-interior')
 g.menu_camera.position=Vector3(-2,3,-2);g.menu_camera.look_at(Vector3(-14,3,-13));await shot('district-landmark')
 quit()
