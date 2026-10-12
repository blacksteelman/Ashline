extends SceneTree
# Sprint-out: pulling the trigger while sprinting must lower the weapon and fire, while a
# held trigger must not fire through the transition and must not fire an extra round.
# Waits poll the game state, because a headless physics step is not a wall-clock frame.
var checks=0
var failures=0
func expect(ok: bool, label: String):
 checks+=1
 print('PASS ' if ok else 'FAIL ',label)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func wait_until(predicate: Callable, seconds: float=3.0) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000.0)
 while Time.get_ticks_msec()<deadline:
  if predicate.call():return true
  await physics_frame
 return predicate.call()
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g)
 g.settings.mode='tdm';g.settings.classes=[]
 g.start_match(false)
 for f in g.fighters:
  if not f.local_player:f.set_physics_process(false);f.global_position=Vector3(28,0,29)
 var p=g.player
 p.local_player=true
 p.global_position=Vector3(-4,.05,-30);p.yaw=PI-.3;p.pitch=0;p.velocity=Vector3.ZERO
 p.weapon_id=0;p.ammo=Arsenal.full_ammo();p.reserves=Arsenal.full_reserves();p.reload_left=0;p.cooldown=0
 p.build_gun()
 await wait_until(func(): return not p.sprinting)
 expect(not p.sprinting,'Player starts walking, not sprinting')
 # Hold sprint and forward until the run state is real.
 Input.action_press('forward');Input.action_press('sprint')
 expect(await wait_until(func(): return p.sprinting),'Holding sprint and forward starts a sprint')
 expect(not p.can_fire(),'A sprinting player cannot fire')
 # Pull the trigger while still sprinting.
 var before=p.ammo[0]
 Input.action_press('fire')
 expect(await wait_until(func(): return not p.sprinting),'Firing during a sprint ends the sprint instead of being ignored')
 expect(p.ammo[0]==before,'The held trigger does not fire during the sprint-out transition')
 expect(await wait_until(func(): return p.sprint_out<=0),'The sprint-out finishes on its own')
 await physics_frame
 expect(p.ammo[0]==before,'A held trigger does not fire after the transition either')
 # Release the trigger and pull again: that is the shot the player asked for, and it
 # happens with sprint still held down.
 Input.action_release('fire')
 await physics_frame
 var ammo_before_new_pull=p.ammo[0]
 Input.action_press('fire')
 expect(await wait_until(func(): return p.ammo[0]<ammo_before_new_pull,1.5),'A fresh trigger pull fires once the weapon is up')
 expect(p.ammo[0]==ammo_before_new_pull-1,'The fresh pull costs exactly one round')
 # Standing still: no sprint-out delay at all.
 Input.action_release('fire');Input.action_release('sprint');Input.action_release('forward')
 expect(await wait_until(func(): return not p.sprinting and p.sprint_out<=0),'Standing still has no sprint-out left')
 p.ammo[0]=Arsenal.full_ammo()[0];p.cooldown=0
 var ammo=p.ammo[0]
 Input.action_press('fire')
 expect(await wait_until(func(): return p.ammo[0]<ammo,1.0),'A standing shot fires immediately')
 Input.action_release('fire')
 print('WEAPON_SPRINT ',checks,' checks, ',failures,' failures')
 quit(0 if failures==0 else 1)
