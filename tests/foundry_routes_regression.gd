extends SceneTree
var checks=0
var failures=0
func expect(ok: bool, message: String):
 if ok:checks+=1;print('PASS ',message)
 else:failures+=1;push_error('FAIL '+message)
func _initialize():call_deferred('run')
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g)
 await process_frame;g.start_match(true)
 for f in g.fighters:
  f.set_physics_process(false);f.collision_layer=0
 await physics_frame;await physics_frame
 var p=g.fighters[0];p.collision_layer=2;p.set_physics_process(true)
 var cases=[
  [Vector3(14,.2,19),Vector3(10,.2,19)],
  [Vector3(10,.2,19),Vector3(14,.2,19)],
  [Vector3(18,.2,21),Vector3(15,.2,21)],
  [Vector3(15,.2,21),Vector3(18,.2,21)],
  [Vector3(31,.18,13),Vector3(31,3.2,26)],
  [Vector3(31,3.2,26),Vector3(31,.18,13)],
  [Vector3(30.46,.18,12.925),Vector3(31,3.2,26)],
  [Vector3(30.449,.18,13.995),Vector3(31,3.2,26)],
  [Vector3(29,.18,18),Vector3(32,.18,18)],
  [Vector3(32,.18,18),Vector3(29,.18,18)],
  # Interior furniture must leave through routes and bench access usable.
  [Vector3(-22,.18,-23.5),Vector3(-14,.18,-18)],
  [Vector3(-14,.18,-18),Vector3(-22,.18,-23.5)],
  [Vector3(-22,3.15,21.5),Vector3(-17,3.15,22.7)],
  [Vector3(-10.5,3.15,14),Vector3(-13.5,3.15,17)],
  [Vector3(24,.18,32),Vector3(20,.18,32)],
  [Vector3(20,.18,32),Vector3(24,.18,32)],
  [Vector3(-21,3.15,14.1),Vector3(-18,3.15,14.1)],
  [Vector3(-18,3.15,14.1),Vector3(-21,3.15,14.1)]]
 for i in cases.size():
  p.global_position=cases[i][0];p.velocity=Vector3.ZERO;p.stuck_time=0;p.recoveries=0;p.bot_target=null;p.bot_think=10000;p.cover_time=0;p.bot_pause=0;p.dead=false;p.health=100;p.respawn_time=10000;p.bot=true;p.local_player=false
  p.set_route(cases[i][1])
  print('ROUTE ',i,' ',p.path)
  var reached=false
  for tick in range(360):
   await physics_frame
   if p.position.distance_to(cases[i][1])<.55:
    reached=true;break
  expect(reached,'Map passage '+str(i)+' traversed by actual Fighter')
  expect(p.recoveries==0,'Map passage '+str(i)+' needs no stuck recovery')
  print('END ',i,' pos=',p.position,' recoveries=',p.recoveries)
 p.set_physics_process(false)
 print('FOUNDRY_ROUTES ',checks,' checks, ',failures,' failures')
 quit(0 if failures==0 else 1)
