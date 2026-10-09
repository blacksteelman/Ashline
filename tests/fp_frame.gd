extends SceneTree
# Fast framing probe for a first-person set (no map): renders the idle pose with FPSetRig's alignment
# for several eye candidates. --kind=2 --offsets="x,y,z[,pitch,yaw,roll,fov];..." [--clip=Idle --at=0.0]
var dir=ProjectSettings.globalize_path('res://build/screenshots-v8')
func _initialize():call_deferred('run')
func run():
 DirAccess.make_dir_recursive_absolute(dir)
 var kind=2;var offsets=[];var clipword='Idle';var at=0.0
 for a in OS.get_cmdline_user_args():
  if a.begins_with('--kind='):kind=int(a.substr(7))
  if a.begins_with('--clip='):clipword=a.substr(7)
  if a.begins_with('--at='):at=float(a.substr(5))
  if a.begins_with('--offsets='):
   for o in a.substr(10).split(';'):
    var p=Array(o.split(',')).map(func(x):return float(x));while p.size()<7:p.append(0.0)
    offsets.append({'cam_offset':Vector3(p[0],p[1],p[2]),'cam_rot':Vector3(p[3],p[4],p[5]),'fov':p[6]})
 var cfg=Arsenal.WEAPONS[kind].fp
 if offsets.is_empty():offsets=[cfg]
 var world=Node3D.new();root.add_child(world)
 var env=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color(.45,.5,.55);e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(.55,.57,.6);e.tonemap_mode=Environment.TONE_MAPPER_AGX;env.environment=e;world.add_child(env)
 var sun=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-45,-30,0);sun.light_energy=1.6
 var cam=Camera3D.new();world.add_child(cam);cam.fov=cfg.get('fov',68.0);cam.near=.01;cam.current=true
 var gun=load(FPSetRig.path(kind)).instantiate();cam.add_child(gun)
 var rig=FPSetRig.new();rig.bind(gun,kind)
 var clip=''
 for n in rig.player.get_animation_list():
  if clipword in n and clip=='':clip=n
 rig.player.play(clip);rig.player.seek(rig.player.get_animation(clip).length*at,true);rig.player.pause()
 for i in 3:await process_frame
 var s=cfg.get('scale',1.0)
 var cb=rig.bone_in_root(rig.cam_bone);cb.basis=cb.basis.orthonormalized()*rig.view_fix
 for i in offsets.size():
  cam.fov=offsets[i].get('fov',0.0) if offsets[i].get('fov',0.0)>0 else cfg.get('fov',68.0)
  gun.transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*s),Vector3.ZERO)*FPSetRig.eye_fix(offsets[i]).affine_inverse()*cb.affine_inverse()
  await process_frame;await RenderingServer.frame_post_draw
  var wb=gun.transform*rig.bone_in_root(rig.weapon_bone)*cfg.frame
  print('BARREL ',(wb*cfg.front-wb*cfg.rear).normalized(),' REAR ',wb*cfg.rear)
  var name='frame%d-%d'%[kind,i];root.get_texture().get_image().save_png(dir+'/'+name+'.png');print('SCREENSHOT ',name,' ',FPSetRig.eye_fix(offsets[i]))
 quit()
