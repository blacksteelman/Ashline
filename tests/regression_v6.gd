extends SceneTree
var passed=0
var failed=0
func _initialize():call_deferred('run')
func expect(value: bool,message: String):
 if value:passed+=1;print('PASS: ',message)
 else:failed+=1;push_error('FAIL: '+message)
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.showcase=true;g.start_match(false)
 for f in g.fighters:f.set_physics_process(false);f.set_process(false);f.dead=true
 var p=g.player;p.dead=false;p.position=Vector3(0,.01,-15);p.weapon_id=3;p.build_gun();p.reload_left=0;p.ammo[3]=12;p.yaw=0;p.pitch=0
 await physics_frame;await physics_frame
 var slide=p.gun.find_child('SlideRig',true,false)
 expect(slide!=null and slide.get_child_count()>=2,'Pistol has an articulated slide with attached sights')
 var original=slide.position
 p.view.fire(3);p.view.update(p,.016)
 expect(slide.position.z-original.z>.04,'Pistol action visibly recoils on its first presentation frame')
 for i in range(30):p.view.update(p,.016)
 expect(slide.position.distance_to(original)<.00001,'Loaded pistol returns to battery after firing')
 p.ammo[3]=0;p.view.update(p,.016)
 expect(slide.position.z-original.z>.04,'Empty pistol holds its slide open')
 var duration=Arsenal.WEAPONS[3].reload*.78;p.reload_left=duration*.08;p.view.update(p,.016)
 expect(slide.position.z-original.z<.012,'Empty reload releases the slide near its final stage')
 p.reload_left=0;p.ammo[3]=12;p.view.update(p,.016)
 expect(slide.position.distance_to(original)<.00001,'Refilled pistol remains in battery')
 p.weapon_id=0;p.build_gun();p.view.fire(0);p.view.update(p,.016)
 var bolt=p.gun.find_child('Bolt carrier',true,false);var baseline=p.view.rest[bolt.get_instance_id()].origin
 expect(bolt.position.z-baseline.z>.04,'Rifle bolt cycles separately from the recoil spring')
 for i in range(30):p.view.update(p,.016)
 expect(bolt.position.distance_to(baseline)<.00001,'Rifle bolt returns exactly to battery')
 var crossing=g.arena.route(Vector3(24,0,-14),Vector3(29,0,-14));var safe=crossing.size()>0
 for i in range(1,crossing.size()):
  var a=crossing[i-1];var b=crossing[i]
  if absf(g.arena.nav_height(a.x,a.y)-g.arena.nav_height(b.x,b.y))>.42:safe=false
 expect(safe,'Ground route never enters a ramp through its raised side')
 var deck=g.arena.route(Vector3(26,0,-22),Vector3(26,2.25,-9))
 expect(deck.size()>8 and deck[deck.size()-1].distance_to(Vector2(26,-9))<.1,'Maintenance deck is connected through the stair run')
 p.bot=true;p.local_player=false;p.bot_target=null;p.bot_think=1000;p.position=Vector3(26,.01,-22);p.velocity=Vector3.ZERO;p.yaw=PI;p.path=deck;p.path_index=0;p.set_physics_process(true)
 for i in range(480):
  await physics_frame
  if p.path_index>=p.path.size():break
 p.set_physics_process(false)
 expect(p.position.y>2.0 and p.position.distance_to(Vector3(26,2.25,-9))<1 and p.recoveries==0,'Real bot ascends the deck without recovery: '+str(p.position))
 p.set_route(Vector3(30,0,-22));p.bot_think=1000;p.set_physics_process(true)
 for i in range(600):
  await physics_frame
  if p.path_index>=p.path.size():break
 p.set_physics_process(false)
 expect(p.position.y<.3 and p.position.distance_to(Vector3(30,0,-22))<1 and p.recoveries==0,'Real bot descends and exits the stair route: '+str(p.position))
 var report={'passed':passed,'failed':failed,'success':failed==0}
 var file=FileAccess.open('res://tests/regression_v6_report.json',FileAccess.WRITE);file.store_string(JSON.stringify(report,'  '))
 print('REGRESSION_V6 ',JSON.stringify(report));quit(0 if failed==0 else 1)
