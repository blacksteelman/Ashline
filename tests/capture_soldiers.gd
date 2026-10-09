extends SceneTree
# Dressed soldier check: both teams, every clip, world weapon in the WeaponSocket.
# DISPLAY=:99 godot --path . --resolution 1280x720 --script tests/capture_soldiers.gd
var dir=ProjectSettings.globalize_path('res://build/screenshots-v8')
func _initialize():call_deferred('run')
func frames(n):
 for i in range(n):await process_frame
func shot(name):
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(dir+'/soldier_'+name+'.png');print('SHOT ',name)
func run():
 DirAccess.make_dir_recursive_absolute(dir)
 var world=Node3D.new();root.add_child(world)
 var env=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color(.55,.6,.66)
 e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(.55,.58,.62);e.tonemap_mode=Environment.TONE_MAPPER_AGX;env.environment=e;world.add_child(env)
 var sun=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-40,-35,0);sun.light_energy=1.7;sun.shadow_enabled=true
 var floor=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(40,40);floor.mesh=pm;world.add_child(floor)
 var cam=Camera3D.new();world.add_child(cam);cam.fov=50;cam.position=Vector3(0,1.4,-6.5);cam.look_at(Vector3(0,.95,0));cam.current=true
 var clips=['Idle','Forward','Left','Sprint','CrouchWalk','Reload','Death']
 var failures=0
 for team in [0,1]:
  var actors=[]
  for i in range(clips.size()):
   var holder=Art.soldier(world,team);holder.position=Vector3((i-3)*1.25,0,0)
   var socket=holder.find_child('WeaponSocket',true,false)
   if not socket:push_error('no WeaponSocket');failures+=1
   else:Art.world_weapon(socket,0)
   var player: AnimationPlayer=holder.find_child('AnimationPlayer',true,false)
   var found=''
   for a in player.get_animation_list():
    if String(a).get_file().begins_with(clips[i]):found=a;break
   if found=='':push_error('missing clip '+clips[i]);failures+=1;continue
   player.play(found);player.seek(player.get_animation(found).length*(.95 if clips[i]=='Death' else .3),true);player.pause()
   actors.append(holder)
  await frames(20);await shot(['aegis','ember'][team])
  cam.position=Vector3(-3.75+1.6,1.5,-2.0);cam.look_at(Vector3(-3.75,1.2,0))
  await frames(5);await shot(['aegis','ember'][team]+'_close')
  cam.position=Vector3(0,1.4,-6.5);cam.look_at(Vector3(0,.95,0))
  for a in actors:a.queue_free()
  await frames(2)
 print('SOLDIER CHECK ','PASS' if failures==0 else 'FAIL')
 quit(1 if failures else 0)
