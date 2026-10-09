extends SceneTree
# Inspect a first-person set: animations, camera bone, and a framed render. --key=fp_ak74m
var dir=ProjectSettings.globalize_path('res://build/screenshots-v8')
func _initialize():call_deferred('run')
func run():
 var key='fp_ak74m'
 for a in OS.get_cmdline_user_args():
  if a.begins_with('--key='):key=a.substr(6)
 var world=Node3D.new();root.add_child(world)
 var env=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color(.45,.5,.55);e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(.55,.57,.6);e.tonemap_mode=Environment.TONE_MAPPER_AGX;env.environment=e;world.add_child(env)
 var sun=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-45,-30,0);sun.light_energy=1.6
 var cam=Camera3D.new();world.add_child(cam);cam.fov=60;cam.near=.01;cam.current=true
 var holder=Node3D.new();cam.add_child(holder)
 var vm=load('res://assets/viewmodels/'+key+'/scene.gltf').instantiate();holder.add_child(vm)
 var sk: Skeleton3D=vm.find_child('Skeleton3D',true,false);var ap: AnimationPlayer=vm.find_child('AnimationPlayer',true,false)
 print('ANIMS ',ap.get_animation_list())
 var idle='';var clipword='Idle';var at=0.0
 for a in OS.get_cmdline_user_args():
  if a.begins_with('--clip='):clipword=a.substr(7)
  if a.begins_with('--at='):at=float(a.substr(5))
 for n in ap.get_animation_list():
  if clipword in n and idle=='':idle=n
 ap.play(idle);ap.seek(ap.get_animation(idle).length*at,true)
 print('PLAY ',idle)
 for i in range(3):await process_frame
 var cb=-1
 for i in sk.get_bone_count():
  if sk.get_bone_name(i).begins_with('Head_Cam') and not '_end' in sk.get_bone_name(i):cb=i
 var hand=-1;var up=-1
 for i in sk.get_bone_count():
  var n=sk.get_bone_name(i)
  if n.begins_with('Hand_R'):hand=i
  if n.begins_with('UpArm_R'):up=i
 # Skeleton-space -> holder-space
 var to_holder=holder.global_transform.affine_inverse()*sk.global_transform
 var c=to_holder*sk.get_bone_global_pose(cb)
 var hp=to_holder*sk.get_bone_global_pose(hand).origin;var sp=to_holder*sk.get_bone_global_pose(up).origin
 print('CAM ',c);print('HAND ',hp,' SHOULDER ',sp,' armlen ',hp.distance_to(sp))
 # Weapon centre: mesh AABBs that are not the arms.
 var gun=Vector3.ZERO;var n=0;var arms=Vector3.ZERO;var m=0
 for mi in vm.find_children('*','MeshInstance3D',true,false):
  var mat=mi.mesh.surface_get_material(0)
  var center=(holder.global_transform.affine_inverse()*mi.global_transform)*mi.get_aabb().get_center()
  print('MESH ',mi.name,' ',mat.resource_name if mat else '',' aabb ',mi.get_aabb().size)
  if mat and mat.resource_name=='arms':arms+=hp;m+=1
  elif mi.name!='Icosphere':gun+=center;n+=1
 print('GUNC ',gun/maxf(1,n))
 # Render candidate view directions from the camera bone.
 var cb_t=to_holder*sk.get_bone_global_pose(cb);cb_t.basis=cb_t.basis.orthonormalized()
 var fwd='+z';var upl='+y'
 for a in OS.get_cmdline_user_args():
  if a.begins_with('--fwd='):fwd=a.substr(6)
  if a.begins_with('--up='):upl=a.substr(5)
 var views={'posz':FPSetRig.axes_basis(fwd,upl)}
 for v in views:
  holder.transform=(cb_t*Transform3D(views[v],Vector3.ZERO)).affine_inverse()
  for i in range(3):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(dir+'/fpprobe_'+key+'_'+v+'.png')
 print('RENDERED')
 quit()
