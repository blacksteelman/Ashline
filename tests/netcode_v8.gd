extends SceneTree
# Netcode checks: snapshot interpolation/extrapolation on clients and host-side lag compensation.
# godot --headless --path . --script tests/netcode_v8.gd
var checks=0
var failures=0
func expect(ok: bool, message: String):
 if ok:checks+=1;print('PASS: ',message)
 else:failures+=1;push_error('FAIL: '+message)
func _initialize():call_deferred('run')
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(false);g.showcase=true
 for f in g.fighters:f.set_physics_process(false);f.set_process(false)
 g.set_physics_process(false) # the test drives server_clock and history itself
 for i in range(4):await physics_frame
 var remote: Fighter=g.fighters[7]
 # Interpolation between two snapshots, bounded extrapolation, teleport snapping.
 remote.net_buffer=[[1.0,Vector3(0,0,0),0.0],[1.1,Vector3(1,0,0),.2]]
 remote.interpolate_network(1.05)
 expect(absf(remote.position.x-.5)<.001 and absf(remote.rotation.y-.1)<.001,'Remote player is interpolated halfway between snapshots')
 remote.interpolate_network(1.15)
 expect(absf(remote.position.x-1.5)<.001,'Late snapshot is extrapolated from the last velocity')
 remote.interpolate_network(1.6)
 expect(absf(remote.position.x-2.0)<.001,'Extrapolation is capped at 100 ms')
 remote.net_buffer=[[1.0,Vector3(0,0,0),0.0],[1.1,Vector3(20,0,0),0.0]]
 remote.interpolate_network(1.05)
 expect(remote.position.x==20,'Respawn teleport snaps instead of sliding across the map')
 remote.net_buffer=[[1.0,Vector3(0,0,0),0.0],[1.1,Vector3(1,0,0),0.0]]
 remote.interpolate_network(.5)
 expect(remote.position.x==0,'View clock before the buffer holds the oldest snapshot')
 # Lag compensation: the shooter saw the target 150 ms ago at A; the target is now at B.
 var shooter: Fighter=g.fighters[0];var target: Fighter=g.fighters[6]
 for f in g.fighters:
  if f!=shooter and f!=target:f.global_position=Vector3(30,-50,30)+Vector3(f.id,0,0)
 shooter.global_position=Vector3(0,.05,20);target.global_position=Vector3(0,.05,10)
 target.global_position=Vector3(3,.05,10)
 g.history.clear();g.server_clock=9.7;g.record_history()
 target.global_position=Vector3(0,.05,10);g.server_clock=10.0;g.record_history()
 target.global_position=Vector3(3,.05,10);g.server_clock=10.15;g.record_history()
 await physics_frame
 var space=shooter.get_world_3d().direct_space_state
 var ray=PhysicsRayQueryParameters3D.create(Vector3(0,1.2,20),Vector3(0,1.2,0),2,[shooter.get_rid()])
 var now=space.intersect_ray(ray)
 expect(now.is_empty() or now.collider!=target,'Without rewind the moved target is not under the old aim')
 var seen=[]
 g.rewound(shooter,10.0,func():seen.append(g.trace(Vector3(0,1.2,20),Vector3(0,1.2,0),shooter)))
 expect(not seen[0].is_empty() and seen[0].collider==target,'Rewound trace hits the target where the shooter saw it')
 expect(not seen[0].is_empty() and absf(seen[0].position.z-10.3)<.02,'Rewound hit lands on the historical capsule surface')
 var wall=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(4,4,.4);shape.shape=box;wall.add_child(shape);g.add_child(wall);wall.global_position=Vector3(0,1,15)
 await physics_frame;await physics_frame
 g.rewound(shooter,10.0,func():seen.append(g.trace(Vector3(0,1.2,20),Vector3(0,1.2,0),shooter)))
 expect(not seen[1].is_empty() and seen[1].collider==wall,'Walls still block rewound shots')
 wall.queue_free();await physics_frame;await physics_frame;seen.pop_back()
 expect(target.global_position.distance_to(Vector3(3,.05,10))<.001,'Target is restored after the rewound trace')
 g.rewound(shooter,9.0,func():seen.append(g.trace(Vector3(0,1.2,20),Vector3(0,1.2,0),shooter)))
 expect(seen[1].is_empty() or seen[1].collider!=target,'Rewind is limited to 250 ms (old claims are clamped)')
 var mid=g.history_at(target.id,10.075)
 expect(mid!=null and absf(mid.x-1.5)<.01,'History is interpolated between recorded ticks')
 print('NETCODE_V8 ',checks,' passed, ',failures,' failed')
 quit(1 if failures else 0)
