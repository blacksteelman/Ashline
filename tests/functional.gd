extends SceneTree
var checks=0
var failures=0
func expect(ok: bool, message: String):
 if not ok:failures+=1;push_error('FAIL: '+message)
 else:checks+=1;print('PASS: '+message)
func _initialize():call_deferred('run')
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g);await process_frame;g.start_match(false)
 for f in g.fighters:
  f.bot=false;f.local_player=false;f.set_physics_process(false);f.position=Vector3(28,0,29)
 var p=g.fighters[0];var enemy=g.fighters[6];p.position=Vector3(0,.01,-15);enemy.position=Vector3(0,.01,-20);p.yaw=0;p.pitch=0;p.ads=true
 await physics_frame;await physics_frame
 expect(g.fighters.size()==12,'6v6 roster')
 expect(g.arena.route(Vector3(-27,0,-29),Vector3(27,0,29)).size()>0,'Cross-map route')
 var a=p.ammo[p.weapon_id];p.shoot();expect(p.ammo[p.weapon_id]==a-1,'Shot consumes round');expect(enemy.health<100,'Hitscan damages visible enemy')
 p.cooldown=0;p.shoot();expect(enemy.dead,'Headshots kill');expect(g.scores==[1,0],'Team score increments exactly once');expect(p.kills==1 and enemy.deaths==1,'K/D recorded')
 p.shoot();expect(g.scores[0]==1,'Dead actor cannot score twice')
 enemy.spawn();expect(not enemy.dead and enemy.health==100,'Respawn resets life and health')
 expect(enemy.aim_dir().z<0,'Ember respawn faces into arena')
 p.spawn();expect(p.aim_dir().z>0,'Aegis respawn faces into arena');p.position=Vector3(0,.01,-15);p.yaw=0
 p.ammo[0]=0;p.start_reload();expect(p.reload_left>0,'Reload starts');p.reload_left=.01;p.set_physics_process(true);await physics_frame;await physics_frame;p.set_physics_process(false);expect(p.ammo[0]==30 and p.reserves[0]==90,'Reload transfers reserve')
 p.switch_weapon();expect(p.weapon_id==3,'Pistol switch');p.switch_weapon();expect(p.weapon_id==0,'Return to primary')
 for c in range(3):p.load_class(c);expect(p.weapon_id==Arsenal.CLASSES[c].primary,'Class selects weapon '+str(c))
 # Real player input through the same physics loop as the game.
 p.load_class(0);p.local_player=true;p.bot=false;p.set_physics_process(true);p.position=Vector3(0,.01,-15);p.yaw=0;p.pitch=0;enemy.position=Vector3(0,.01,-22)
 Input.action_press('forward')
 for tick in range(20):await physics_frame
 expect(p.position.z < -15.5,'WASD moves player')
 var walk_speed=Vector2(p.velocity.x,p.velocity.z).length()
 Input.action_press('sprint')
 for tick in range(12):await physics_frame
 expect(Vector2(p.velocity.x,p.velocity.z).length()>walk_speed,'Sprint increases movement speed')
 Input.action_release('forward');Input.action_release('sprint');Input.action_press('crouch')
 for tick in range(6):await physics_frame
 expect(p.crouched and p.col.shape.height<1.8,'Crouch changes collision hull')
 Input.action_release('crouch');Input.action_press('ads')
 for tick in range(12):await physics_frame
 expect(p.ads and p.camera.fov<g.settings.fov,'ADS transitions field of view')
 Input.action_release('ads');Input.action_press('jump');await physics_frame;Input.action_release('jump')
 for tick in range(5):await physics_frame
 expect(p.position.y>.15,'Jump leaves floor')
 p.set_physics_process(false);p.position=Vector3(0,.01,-15);p.velocity=Vector3.ZERO;p.cooldown=0;p.pitch=0;p.sprinting=false;p.reload_left=0;enemy.dead=false;enemy.collision_layer=2;enemy.position=Vector3(0,.01,-20);enemy.health=100
 await physics_frame;await physics_frame
 p.shoot();expect(p.kick>0 and p.pitch>0,'Shot drives weapon and camera recoil')
 for kind in range(4):
  p.weapon_id=kind;p.ammo[kind]=10;p.cooldown=0;p.pitch=0;enemy.dead=false;enemy.collision_layer=2;enemy.health=100
  p.shoot();expect(enemy.health<100,'Weapon '+str(kind)+' hits and damages')
 # The visible moving pieces are part of the actual imported viewmodel.
 p.weapon_id=0;p.build_gun();p.ammo[0]=12;p.reload_left=0
 var arms: Skeleton3D=p.gun.find_child('Skeleton3D',true,false)
 var mag_bone=-1;var hand=-1
 if arms:
  for i in arms.get_bone_count():
   var n=arms.get_bone_name(i)
   if mag_bone<0 and n.begins_with('Pmag'):mag_bone=i
   if hand<0 and n.begins_with('Hand_L'):hand=i
 expect(p.view is FPSetRig and arms!=null and mag_bone>=0,'Viewmodel is the animated first-person set with a magazine bone')
 p.view.stop_action();p.view.player.advance(1.0);arms.force_update_all_bone_transforms()
 var seated=arms.get_bone_global_pose(mag_bone).origin
 p.start_reload();var duration=p.reload_left
 var travel=0.0;var near=INF
 for k in range(1,10):
  p.reload_left=duration*(1.0-k/10.0);p.view.update(p,.016);p.view.player.advance(.1);p.view.update(p,.016);p.view.player.advance(0);arms.force_update_all_bone_transforms()
  var at=arms.get_bone_global_pose(mag_bone).origin
  travel=maxf(travel,at.distance_to(seated));near=minf(near,arms.get_bone_global_pose(hand).origin.distance_to(at))
 expect(travel>.05,'Magazine moves out during reload')
 expect(near<.6,'Supporting hand works the magazine')
 p.reload_left=0;p.view.update(p,.016);p.view.player.advance(1.0);arms.force_update_all_bone_transforms()
 expect(arms.get_bone_global_pose(mag_bone).origin.distance_to(seated)<.02,'Magazine returns to its seated pose')
 p.view.fire(0);p.view.spring_step(.016)
 expect(p.view.recoil_position.z>0,'Spring recoil moves weapon rearward')
 for tick in range(100):p.view.spring_step(.016)
 expect(p.view.recoil_position.length()<.001,'Spring recoil settles without drift')
 # Spatial effects, headshots while crouched, and authoritative damage through walls.
 enemy.position=Vector3(0,.01,-20);enemy.dead=false;enemy.health=100;enemy.crouched=true;enemy.col.shape.height=1.2;enemy.col.position.y=.6;enemy.collision_layer=2
 p.position=Vector3(0,.01,-15);p.pitch=atan2(1.11-1.62,5);p.yaw=0;p.cooldown=0;p.ads=true;p.ammo[0]=10
 await physics_frame;await physics_frame
 p.shoot();expect(enemy.health<40,'Crouched head hit uses head multiplier')
 p.cooldown=0;p.shoot();expect(enemy.dead,'Crouched headshots can kill')
 p.pitch=0;enemy.spawn();enemy.position=Vector3(0,.01,-20);p.position=Vector3(0,.01,-15)
 var wall=Art.box(g,Vector3(0,1,-17.5),Vector3(3,2,.5),Art.mat('concrete'),true)
 await physics_frame;await physics_frame
 p.cooldown=0;p.shoot();expect(enemy.health==100,'Wall blocks weapon damage')
 var detour=g.arena.route(Vector3(14,.2,30),Vector3(14,.2,-30))
 expect(detour.size()>30,'Navigation routes around the foundry hall walls')
 p.local_player=false
 var before=p.grenades;p.throw_grenade();expect(p.grenades==before-1 and g.grenades.size()==1,'Frag creates physical grenade')
 g.start_match(false);await process_frame;expect(g.grenades.is_empty(),'Round restart clears grenades')
 p=g.fighters[0];enemy=g.fighters[6]
 for f in g.fighters:f.set_physics_process(false)
 for i in range(7):enemy.dead=false;enemy.health=1;enemy.hurt(100,p,'TORSO')
 expect(p.rewards==[3,5,7],'Streak rewards 3/5/7');p.activate_streak();expect(g.radar_time[0]==20,'Recon reward activates radar')
 g.score_limit=7;g._process(.02);expect(g.state=='results','Score limit ends match')
 g.start_match(false);expect(g.state=='match' and g.scores==[0,0],'Next match starts with cleared score')
 g.queue_class(2);expect(g.player.weapon_id==0,'Queued class keeps current-life weapon');g.player.spawn();expect(g.player.weapon_id==2 and g.player.class_id==2,'Queued class applies on respawn')
 g.settings.sensitivity=1.7;g.save_settings();g.settings.sensitivity=.1;g.load_settings();expect(g.settings.sensitivity==1.7,'Settings persist')
 g.use_streak(g.player,5);g.use_streak(g.player,7);g.start_match(false)
 for f in g.fighters:f.set_physics_process(false)
 await create_timer(1.5).timeout
 expect(g.scores==[0,0],'Old support timers cannot damage or score in new match')
 var frag_owner=g.player;frag_owner.throw_grenade();g.leave_match();expect(g.grenades.is_empty() and g.fighters.is_empty(),'Leaving match clears grenade ownership safely')
 var out=FileAccess.open('res://tests/functional_report.json',FileAccess.WRITE);out.store_string(JSON.stringify({'passed':checks,'failed':failures,'success':failures==0},'  '));print('FUNCTIONAL_OK ' if failures==0 else 'FUNCTIONAL_FAILED ',checks,' failed=',failures);quit(0 if failures==0 else 1)
