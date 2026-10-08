extends SceneTree
func _initialize():call_deferred('run')
func run():
 var game=load('res://main.tscn').instantiate();root.add_child(game);await process_frame;game.start_match(false)
 for f in game.fighters:
  f.set_physics_process(false);f.position=Vector3(-27,0,-29)
 var p=game.player;p.position=Vector3(26,.01,-22);p.yaw=PI;p.velocity=Vector3.ZERO;p.set_physics_process(true)
 Input.action_press('forward')
 for i in range(360):
  await physics_frame
  if p.position.y>2.0 and p.position.z> -12:break
 Input.action_release('forward');print('STAIR_POSITION ',p.position)
 if p.position.y>2.0 and p.position.z> -13:print('STAIRS_OK');quit()
 else:push_error('Stair ascent failed');quit(1)
