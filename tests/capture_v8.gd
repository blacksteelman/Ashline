extends SceneTree
# Real engine frames for visual review. Usage:
# godot --path . --resolution 1600x900 --script tests/capture_v8.gd -- --graphics=2 [--views=a,b]
var g: Node3D
var directory=ProjectSettings.globalize_path('res://build/screenshots-v8')
const VIEWS={
 'street':[Vector3(1.5,1.7,-30),Vector3(0,1.5,0)],
 'overview':[Vector3(42,30,-52),Vector3(0,0,0)],
 'intersection':[Vector3(-6,2.0,-9),Vector3(-15,3,14)],
 'apartment_in':[Vector3(-10.5,1.8,13),Vector3(-20,1.2,22)],
 'apartment_up':[Vector3(-22,4.9,13),Vector3(-9,3.6,18)],
 'market':[Vector3(-1,1.7,-15),Vector3(-12,2,-20)],
 'hall':[Vector3(14,1.8,14),Vector3(28,2.5,28)],
 'yard':[Vector3(11,1.8,-12),Vector3(25,1.5,-32)],
 'alley':[Vector3(-30,1.7,-4),Vector3(-28,2,20)],
}
func _initialize():call_deferred('run')
func frames(n: int):
 for i in range(n):await process_frame
func shot(name: String):
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(directory+'/'+name+'.png');print('SCREENSHOT ',name)
func run():
 DirAccess.make_dir_recursive_absolute(directory)
 var wanted=[]
 for a in OS.get_cmdline_user_args():
  if a.begins_with('--views='):wanted=a.substr(8).split(',')
 g=load('res://main.tscn').instantiate();root.add_child(g);g.showcase=true;g.start_match(false)
 for f in g.fighters:
  if f.local_player:continue
  f.set_physics_process(false)
 var p=g.player;p.position=Vector3(1.5,.1,-30);p.yaw=PI;p.pitch=0;p.velocity=Vector3.ZERO
 # Let SDFGI cascades and auto exposure settle before any capture.
 await frames(90)
 if wanted.is_empty() or 'fp' in wanted:
  await shot('fp-ready')
  p.ads=true;await frames(30);await shot('fp-ads');p.ads=false;await frames(20)
 g.hud.visible=false;g.menu_camera.current=true
 for key in VIEWS:
  if not wanted.is_empty() and key not in wanted:continue
  g.menu_camera.fov=70;g.menu_camera.position=VIEWS[key][0];g.menu_camera.look_at(VIEWS[key][1])
  await frames(45);await shot(key)
 quit()
