extends SceneTree
# Close-ups of a soldier's grip on the world weapon: --weapon=0 --clip=Idle --team=0 -> build/screenshots-v8/grip_*.png
# DISPLAY=:99 godot --path . --resolution 1280x720 --script tests/capture_grip.gd
var dir=ProjectSettings.globalize_path('res://build/screenshots-v8')
func _initialize():call_deferred('run')
func frames(n):
 for i in range(n):await process_frame
func run():
 DirAccess.make_dir_recursive_absolute(dir)
 var weapon=0;var clip='Idle';var team=0;var use_ik=true
 for a in OS.get_cmdline_user_args():
  if a.begins_with('--weapon='):weapon=int(a.substr(9))
  if a.begins_with('--clip='):clip=a.substr(7)
  if a.begins_with('--team='):team=int(a.substr(7))
  if a=='--noik':use_ik=false
 var world=Node3D.new();root.add_child(world)
 var env=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color(.55,.6,.66)
 e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(.6,.62,.66);e.tonemap_mode=Environment.TONE_MAPPER_AGX;env.environment=e;world.add_child(env)
 var sun=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-40,-35,0);sun.light_energy=1.7
 var cam=Camera3D.new();world.add_child(cam);cam.fov=35;cam.current=true;cam.near=.02
 var holder=Art.soldier(world,team)
 var socket=holder.find_child('WeaponSocket',true,false)
 var gun=Art.world_weapon(socket,weapon)
 if '--measure' in OS.get_cmdline_user_args():GripIK.measure=true
 if use_ik or GripIK.measure:GripIK.attach(holder,socket,gun)
 var player: AnimationPlayer=holder.find_child('AnimationPlayer',true,false)
 for a in player.get_animation_list():
  if String(a).get_file().begins_with(clip):player.play(a);player.seek(player.get_animation(a).length*.3,true);player.pause();break
 await frames(10)
 var sk: Skeleton3D=holder.find_child('Skeleton3D',true,false)
 for side in ['L','R']:
  var wrist=sk.global_transform*sk.get_bone_global_pose(sk.find_bone('Hand.'+side)).origin
  print('WRIST ',side,' socket ',socket.global_transform.affine_inverse()*wrist,' ik ',use_ik,' world ',wrist)
 print('SOCKET ',socket.global_transform,' SK ',sk.global_transform)
 for bn in ['Chest','UpperArm.L','Forearm.L','Hand.L','UpperArm.R','Forearm.R','Hand.R','Weapon']:print('  ',bn,' ',sk.get_bone_global_pose(sk.find_bone(bn)).origin,' parent ',sk.get_bone_parent(sk.find_bone(bn)))
 # Soldier faces +Z (holder rotated by PI): views from his right, left, front-right and above the shoulder.
 var target=socket.global_position
 var views={'right':Vector3(-1.1,0.12,-0.2),'left':Vector3(1.1,0.12,-0.2)}
 for name in views:
  cam.position=target+views[name];cam.look_at(target+Vector3(0,0,-0.15))
  await frames(3);await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(dir+'/grip_%s_w%d_%s%s.png'%[clip,weapon,name,'' if use_ik else '_noik']);print('SHOT ',name)
 quit()
