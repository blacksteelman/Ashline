extends SceneTree
func _initialize():call_deferred('run')
func capture(label:String):
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://build/ragdoll-review/'+label+'.png'))
 print('COMBAT ',label)
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(false)
 g.set_process(false);g.set_physics_process(false)
 for f in g.fighters:f.set_process(false);f.set_physics_process(false);f.model.visible=false
 var p=g.player;p.global_position=Vector3(1.5,.18,-30);p.yaw=PI-.16;p.rotation.y=p.yaw;p.camera.current=true
 var enemy=g.fighters[6];enemy.global_position=p.global_position+Vector3(3,0,4);enemy.model.visible=true;enemy.yaw=0;enemy.rotation.y=0
 enemy.body_motion.tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 for i in 35:
  p._process(1.0/60);enemy.body_motion.update(1.0/60);enemy.body_motion.tree.set('parameters/Air/blend_amount',0.0);enemy.body_motion.tree.advance(1.0/60)
 p.hurt(8,enemy,'TORSO');await capture('incoming-damage')
 p.hurt(200,enemy,'HEAD');p._process(1.0/60)
 for i in 90:await physics_frame;p._process(1.0/60)
 await capture('death-camera')
 p.spawn();p.global_position=Vector3(1.5,.18,-30);p.yaw=PI-.16;p.rotation.y=p.yaw
 for i in 35:p._process(1.0/60)
 await capture('first-person-respawn')
 g.queue_free();g=null;p=null;enemy=null;await process_frame;await process_frame;quit()
