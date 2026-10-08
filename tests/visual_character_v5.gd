extends SceneTree
var g: Node3D
var soldier: Fighter
var directory=ProjectSettings.globalize_path('res://build/screenshots-v5')
func _initialize():call_deferred('run')
func shot(name: String):
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(directory+'/'+name+'.png');print('SCREENSHOT ',name)
func pose(name: String,time: float):
 var m=soldier.body_motion;var player=m.tree.get_node(m.tree.anim_player)
 m.tree.active=false;player.play(m.clips[name]);player.seek(time,true);player.pause();m.skeleton.force_update_all_bone_transforms()
func run():
 DirAccess.make_dir_recursive_absolute(directory)
 g=load('res://main.tscn').instantiate();root.add_child(g);g.showcase=true;g.start_match(false)
 await create_timer(.3).timeout
 for f in g.fighters:
  f.set_physics_process(false);f.set_process(false);f.model.visible=false
  if f.body_motion:f.body_motion.tree.active=false
 soldier=g.fighters[6];soldier.dead=false;soldier.model.visible=true;soldier.position=Vector3(0,0,-15);soldier.rotation=Vector3.ZERO;soldier.pitch=0;soldier.velocity=Vector3.ZERO
 g.hud.visible=false;g.menu_camera.position=Vector3(1.4,1.4,-17.8);g.menu_camera.look_at(soldier.position+Vector3(0,.95,0));g.menu_camera.current=true
 for state in [['Idle',.3,'character-idle'],['Forward',.2,'character-run'],['Left',.2,'character-strafe'],['CrouchIdle',.3,'character-crouch'],['Reload',.5,'character-reload'],['Death',.95,'character-death']]:
  pose(state[0],state[1]);await shot(state[2])
 pose('Idle',.3);soldier.position=Vector3(0,0,-11.5)
 g.player.position=Vector3(0,0,-15);g.player.yaw=PI;g.player.pitch=0;g.player._process(.016);g.player.camera.current=true;g.hud.visible=true
 await shot('combat-opponent')
 quit()
