extends SceneTree
# Fast framing probe for a first-person set (no map): renders the idle pose with FPSetRig's alignment
# for several eye candidates. --kind=2 --offsets="x,y,z[,pitch,yaw,roll,fov];..." [--clip=Idle --at=0.0 --ads | --side --eye=.24 --rear=x,y,z --front=x,y,z]
var dir=ProjectSettings.globalize_path('res://build/screenshots-v8')
func _initialize():call_deferred('run')
func run():
 DirAccess.make_dir_recursive_absolute(dir)
 var kind=2;var offsets=[];var clipword='Idle';var at=0.0;var ads=false;var over={}
 for a in OS.get_cmdline_user_args():
  if a.begins_with('--kind='):kind=int(a.substr(7))
  if a.begins_with('--clip='):clipword=a.substr(7)
  if a.begins_with('--at='):at=float(a.substr(5))
  if a=='--ads':ads=true
  if a=='--side':over['side']=true
  if a=='--top':over['side']=true;over['top']=true
  if a=='--marks':over['marks']=true
  if a.begins_with('--team='):over['team']=int(a.substr(7))
  for key in ['eye','rear','front','fov_ads','ads_roll']:
   if a.begins_with('--'+key+'='):
    var v=Array(a.substr(key.length()+3).split(',')).map(func(x):return float(x))
    over[key]=v[0] if v.size()==1 else Vector3(v[0],v[1],v[2])
  if a.begins_with('--offsets='):
   for o in a.substr(10).split(';'):
    var p=Array(o.split(',')).map(func(x):return float(x));while p.size()<7:p.append(0.0)
    offsets.append({'cam_offset':Vector3(p[0],p[1],p[2]),'cam_rot':Vector3(p[3],p[4],p[5]),'fov':p[6]})
 var cfg=Arsenal.WEAPONS[kind].fp.duplicate();cfg.merge(over,true)
 if offsets.is_empty():offsets=[cfg]
 var world=Node3D.new();root.add_child(world)
 var env=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color(.45,.5,.55);e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(.55,.57,.6);e.tonemap_mode=Environment.TONE_MAPPER_AGX;env.environment=e;world.add_child(env)
 var sun=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-45,-30,0);sun.light_energy=1.6
 var cam=Camera3D.new();world.add_child(cam);cam.fov=cfg.get('fov',68.0);cam.near=.01;cam.current=true
 var gun=load(FPSetRig.path(kind)).instantiate();cam.add_child(gun)
 if cfg.has('team'):FPSetRig.dress_arms(gun,cfg.team)
 var rig=FPSetRig.new();rig.bind(gun,kind)
 var clip=''
 for n in rig.player.get_animation_list():
  if clipword in n and clip=='':clip=n
 if clip=='':
  push_error('No animation matching '+clipword+' in weapon '+str(kind));quit(2);return
 # A paused crossfade otherwise leaves the old pose in the capture indefinitely.
 rig.player.play(clip,0.0);rig.player.seek(rig.player.get_animation(clip).length*at,true);rig.player.advance(0);rig.player.pause()
 rig.skeleton.force_update_all_bone_transforms()
 for i in 3:await process_frame
 var s=cfg.get('scale',1.0)
 var cb=rig.camera_in_root();cb.basis=cb.basis.orthonormalized()*rig.view_fix
 for i in offsets.size():
  cam.fov=offsets[i].get('fov',0.0) if offsets[i].get('fov',0.0)>0 else cfg.get('fov',68.0)
  gun.transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*s),Vector3.ZERO)*FPSetRig.eye_fix(offsets[i]).affine_inverse()*cb.affine_inverse()
  var wb=gun.transform*rig.bone_in_root(rig.weapon_bone)*cfg.frame
  if ads:
   gun.transform=FPSetRig.ads_offset(cfg,wb)*gun.transform
   cam.fov=cfg.get('fov_ads',55.0)
  wb=gun.transform*rig.bone_in_root(rig.weapon_bone)*cfg.frame
  if cfg.get('side',false):
   # Orthographic side view along the barrel frame's x axis, red markers on rear/front sight points.
   var r=wb*cfg.rear;var f=wb*cfg.front;var mid=(r+f)*.5
   var side=cam.get_parent().get_node_or_null('SideCam') as Camera3D
   if not side:side=Camera3D.new();side.name='SideCam';cam.get_parent().add_child(side)
   side.projection=Camera3D.PROJECTION_ORTHOGONAL;side.size=r.distance_to(f)*1.6;side.near=.001
   var view_axis=wb.basis.y.normalized() if cfg.get('top',false) else wb.basis.x.normalized()
   var up_axis=-wb.basis.x.normalized() if cfg.get('top',false) else wb.basis.y.normalized()
   side.global_position=cam.global_transform*(mid+view_axis*.5)
   side.look_at(cam.global_transform*mid,cam.global_transform.basis*up_axis);side.current=true
  if cfg.get('side',false) or cfg.get('marks',false):
   for point in [wb*cfg.rear,wb*cfg.front]:
    var m=MeshInstance3D.new();var sm=SphereMesh.new();sm.radius=.002 if not cfg.get('side',false) else (wb*cfg.rear).distance_to(wb*cfg.front)*.013;sm.height=sm.radius*2;m.mesh=sm
    var mat=StandardMaterial3D.new();mat.albedo_color=Color.RED;mat.no_depth_test=true;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;sm.material=mat
    cam.add_child(m);m.position=point
  await process_frame;await RenderingServer.frame_post_draw
  print('BARREL ',(wb*cfg.front-wb*cfg.rear).normalized(),' REAR ',wb*cfg.rear)
  var name='frame%d-%d'%[kind,i];root.get_texture().get_image().save_png(dir+'/'+name+'.png');print('SCREENSHOT ',name,' ',FPSetRig.eye_fix(offsets[i]))
 quit()
