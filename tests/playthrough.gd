extends SceneTree
var g: Node3D
var failures=0
func check(ok: bool, title: String):
 if ok:print('PASS: ',title)
 else:failures+=1;push_error(title)
func click(text: String):
 await process_frame
 for button in g.ui.find_children('*','Button',true,false):
  if text in button.text:
   var pos=button.get_global_rect().get_center()
   print('CLICK ',button.text,' ',pos,' rect=',button.get_global_rect(),' viewport=',root.get_visible_rect())
   var motion=InputEventMouseMotion.new();motion.position=pos;motion.global_position=pos;root.push_input(motion,true)
   var press=InputEventMouseButton.new();press.position=pos;press.global_position=pos;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;root.push_input(press,true)
   await process_frame
   press=press.duplicate();press.pressed=false;root.push_input(press,true);await process_frame
   return
 failures+=1;push_error('Button not found: '+text)
func _initialize():call_deferred('run')
func run():
 g=load('res://main.tscn').instantiate();root.add_child(g);await process_frame
 await click('PLAY');await click('DEPLOY')
 check(g.state=='match' and g.player!=null,'Mouse clicks navigate Play → class → match')
 if g.player==null:quit(1);return
 for f in g.fighters:f.set_physics_process(false);f.set_process(false)
 var p=g.player;var enemy=g.fighters[6]
 p.position=Vector3(0,.01,-15);p.yaw=0;p.pitch=0;p.set_physics_process(true)
 for f in g.fighters:
  if f!=p:f.position=Vector3(28,0,28)
 enemy.position=Vector3(0,.01,-20);enemy.health=30;enemy.collision_layer=2
 await physics_frame;await physics_frame
 Input.action_press('fire');await physics_frame;await physics_frame;Input.action_release('fire')
 check(enemy.dead and p.kills==1 and g.scores[0]==1,'Player input produces an elimination and updates team score')
 p.hurt(200,enemy,'TORSO');check(p.dead,'Player dies to combat damage')
 await create_timer(2.6).timeout
 check(not p.dead and p.health==100,'Player automatically respawns')
 p.set_physics_process(false)
 for i in range(7):enemy.dead=false;enemy.health=1;enemy.hurt(100,p,'TORSO')
 check(p.rewards==[3,5,7],'New life earns 3/5/7 streak rewards')
 p.activate_streak();check(g.radar_time[p.team]>0,'Earned recon can be activated')
 g.score_limit=8;g._process(.016);check(g.state=='results','Score limit opens results')
 await click('NEXT MATCH');check(g.state=='match' and g.scores==[0,0],'Results button starts a fresh match')
 g.pause_menu();await click('SETTINGS')
 check(g.ui.find_children('*','HSlider',true,false).size()==3,'Settings reachable inside a match')
 await click('BACK');await click('RESUME');check(not g.menu_open,'Match resumes from the menu')
 print('PLAYTHROUGH ', 'OK' if failures==0 else 'FAILED', ' failures=',failures)
 quit(0 if failures==0 else 1)
