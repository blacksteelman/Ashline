extends SceneTree
# Isolated first-person viewmodel check: stock materials vs viewmodel shader,
# AnimationPlayer vs FirstPersonRig tree. Frames: build/screenshots-v8/iso_*.png
var dir=ProjectSettings.globalize_path('res://build/screenshots-v8')
func _initialize():call_deferred('run')
func frames(n):
 for i in range(n):await process_frame
func shot(name):
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(dir+'/iso_'+name+'.png');print('SHOT ',name)
func run():
 var model=OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size()>0 else 'ar'
 var world=Node3D.new();root.add_child(world)
 var env=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color(.45,.5,.55);e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(.6,.62,.65);env.environment=e;world.add_child(env)
 var sun=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-50,-30,0);sun.light_energy=1.6
 var cam=Camera3D.new();world.add_child(cam);cam.fov=52;cam.near=.01;cam.current=true
 for variant in ['tree_only','tree_bolt']:
  var vm2=load('res://assets/viewmodels/vm_'+model+'.glb').instantiate();cam.add_child(vm2)
  ViewmodelMaterial.apply(vm2);ViewmodelMaterial.update_projection(52,52)
  var rig=FirstPersonRig.new();rig.gun=vm2
  rig.skeleton=vm2.find_child('Skeleton3D',true,false);rig.player=vm2.find_child('AnimationPlayer',true,false)
  rig.build_tree()
  if variant=='tree_bolt':
   rig.bolt_modifier=load('res://scripts/bolt_modifier.gd').new();rig.bolt_modifier.rig=rig;rig.skeleton.add_child(rig.bolt_modifier)
  await frames(10);await shot(model+'_'+variant)
  vm2.queue_free();await frames(2)
 for variant in ['stock_player','shader_player']:
  var vm=load('res://assets/viewmodels/vm_'+model+'.glb').instantiate();cam.add_child(vm)
  if variant.begins_with('shader'):ViewmodelMaterial.apply(vm);ViewmodelMaterial.update_projection(52,52)
  var ap: AnimationPlayer=vm.find_child('AnimationPlayer',true,false)
  print('clips ',ap.get_animation_list())
  ap.play('idle');await frames(10);await shot(model+'_'+variant)
  vm.queue_free();await frames(2)
 quit()
