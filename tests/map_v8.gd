extends SceneTree
# Foundry District v8: navigation reaches every level and a physical bot walks there.
var failures=0
var results=[]
func check(ok: bool, label: String):
 results.append({'ok':ok,'check':label});print(('PASS ' if ok else 'FAIL ')+label)
 if not ok:failures+=1
func _initialize():call_deferred('run')
func run():
 var game=load('res://main.tscn').instantiate();root.add_child(game);await process_frame
 game.start_match(true)
 for i in range(5):await physics_frame
 var arena=game.arena
 check(arena.nav_ready and arena.navigation.get_point_count()>5000,'Navigation sampled from physics (%d points)' % arena.navigation.get_point_count())
 check(arena.spawns[0].size()>=6 and arena.spawns[1].size()>=6,'Both teams have spawn points')
 # Spawns stand on open ground, not inside geometry.
 var space=game.get_world_3d().direct_space_state;var capsule=CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.8
 var q=PhysicsShapeQueryParameters3D.new();q.shape=capsule;q.collision_mask=1|8;var clear=true
 for team in range(2):
  for p in arena.spawns[team]:
   q.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*1.0)
   if not space.intersect_shape(q,1).is_empty():clear=false;print('  blocked spawn ',p)
 check(clear,'Every spawn point is free of collision')
 var levels={'apartment first floor':Vector3(-12,3.2,14),'foundry catwalk':Vector3(31.5,3.2,25),'loading dock':Vector3(31.5,1.3,-28),'market shop':Vector3(-14,.2,-18),'west alley':Vector3(-30,.2,0)}
 for label in levels:
  var target: Vector3=levels[label]
  var path=arena.route(Vector3(0,0,-40),target)
  var end=arena.navigation.get_point_position(arena.navigation.get_closest_point(target))
  check(path.size()>5 and end.distance_to(target)<1.5,'Route from Aegis spawn to '+label)
 for p in arena.patrol:
  var reach=arena.navigation.get_point_position(arena.navigation.get_closest_point(p))
  if reach.distance_to(p)>1.5:check(false,'Patrol point on navmesh '+str(p))
 # Physical traversal with the real character controller.
 for f in game.fighters:f.set_physics_process(false);f.position=Vector3(0,-20,0)
 var bot=game.fighters[1];bot.set_physics_process(true);bot.bot=false;bot.network_input={}
 bot.global_position=Vector3(-6,.3,8.5);bot.velocity=Vector3.ZERO
 # Drive it with route following only (no combat AI).
 bot.set_physics_process(false)
 var ok=await drive(game,bot,Vector3(-12,3.2,14),25.0)
 check(ok,'Bot climbs the Ashline House stairwell to the first floor')
 bot.global_position=Vector3(22,.3,8.0);bot.velocity=Vector3.ZERO
 ok=await drive(game,bot,Vector3(31.5,3.2,26),25.0)
 check(ok,'Bot climbs the foundry stair onto the catwalk')
 bot.global_position=Vector3(20,.3,-12.0);bot.velocity=Vector3.ZERO
 ok=await drive(game,bot,Vector3(31.5,1.3,-28),25.0)
 check(ok,'Bot climbs onto the loading dock')
 var file=FileAccess.open('res://tests/map_v8_report.json',FileAccess.WRITE)
 if file:file.store_string(JSON.stringify({'failures':failures,'results':results},'  '))
 print('MAP_V8 failures=',failures);quit(1 if failures else 0)
func drive(game, actor, target: Vector3, limit: float) -> bool:
 actor.set_route(target);var t=0.0
 while t<limit:
  actor.follow_route(1.0/60.0)
  actor.network_input={'x':actor.move_wish.x,'z':actor.move_wish.y,'yaw':actor.yaw,'pitch':0.0}
  actor._physics_process(1.0/60.0)
  await physics_frame;t+=1.0/60.0
  if actor.global_position.distance_to(target)<1.3 and absf(actor.global_position.y-target.y)<.6:return true
  if actor.path_index>=actor.path.size():actor.set_route(target)
 print('  stopped at ',actor.global_position,' heading for ',target)
 return false
