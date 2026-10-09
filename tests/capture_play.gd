extends SceneTree
# Plays the local player with real input actions (physics on) and captures frames:
# hip, ADS held, firing in ADS, reload, sprint. godot --path . --script tests/capture_play.gd -- --graphics=1
var directory=ProjectSettings.globalize_path('res://build/screenshots-v8')
func _initialize():call_deferred('run')
func frames(n):
 for i in range(n):await process_frame
func shot(name):
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(directory+'/play_'+name+'.png');print('SHOT ',name)
func run():
 DirAccess.make_dir_recursive_absolute(directory)
 var weapon=0
 for a in OS.get_cmdline_user_args():
  if a.begins_with('--weapon='):weapon=int(a.substr(9))
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.showcase=true;g.start_match(false)
 for f in g.fighters:
  if not f.local_player:f.set_physics_process(false);f.position=Vector3(0,-30,0)
 var p=g.player;p.global_position=Vector3(1.5,.1,-30);p.yaw=PI;p.pitch=0
 if weapon!=0:p.load_class(weapon) if weapon<3 else p.switch_weapon()
 await frames(60);await shot('hip')
 Input.action_press('ads');await frames(40);print('ADS ads=',p.ads,' blend=',p.view.aim_blend,' action=',p.view.action,' fov=',p.camera.fov);await shot('ads')
 Input.action_press('fire');await frames(6);await shot('ads_fire');Input.action_release('fire');Input.action_release('ads');await frames(30)
 p.ammo[p.weapon_id]=3;Input.action_press('reload');await frames(2);Input.action_release('reload');await frames(40);await shot('reload')
 await frames(120)
 Input.action_press('forward');Input.action_press('sprint');await frames(40);await shot('sprint');Input.action_release('sprint');await frames(25);await shot('walk');Input.action_release('forward')
 quit()
