extends SceneTree
# Gunfire FX check: the player fires at a wall; frames during the shot (flash) and after (holes, dust).
# DISPLAY=:99 godot --path . --resolution 1280x720 --script tests/capture_fire.gd -- [--weapon=1]
func _initialize():call_deferred('run')
func frames(n):
 for i in range(n):await process_frame
func shot(name):
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://build/screenshots-v8/fire_'+name+'.png'));print('SHOT ',name)
func run():
 var weapon=1
 for a in OS.get_cmdline_user_args():
  if a.begins_with('--weapon='):weapon=int(a.substr(9))
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(false)
 for f in g.fighters:
  if not f.local_player:f.set_physics_process(false);f.position=Vector3(0,-30,0)
 var p=g.player;p.set_physics_process(false)
 p.global_position=Vector3(1.5,.1,-30);p.yaw=PI+1.95;p.pitch=-.32;p.rotation.y=0
 # Stand 3 m from whatever wall is ahead, so holes and dust are readable.
 await frames(2)
 var hit=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p.eye(),p.eye()+p.aim_dir()*60,1))
 if not hit.is_empty():p.global_position+=p.aim_dir()*maxf(0,p.eye().distance_to(hit.position)-3.0)*Vector3(1,0,1)
 p.weapon_id=weapon;p.build_gun();await frames(30)
 for i in range(6):
  p.cooldown=0;p.ammo[weapon]=20;p.shoot()
  if i==3:await shot('flash_w%d'%weapon)  # same frame: the flash lives 40 ms
  await frames(1)
 await frames(2);await shot('marks_w%d'%weapon)
 quit()
