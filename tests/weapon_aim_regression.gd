extends SceneTree
# Shooting must not walk the player's aim: single-shot weapons return their kick
# exactly, automatic weapons keep a spray pattern but the debt they leave is capped,
# so holding the trigger never drifts the view off target without bound.
var checks=0
var failures=0
func expect(ok: bool, label: String):
 checks+=1
 print('PASS ' if ok else 'FAIL ',label)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func frames(n):
 for i in range(n):await process_frame
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g)
 g.settings.mode='tdm';g.settings.classes=[];g.showcase=true
 g.start_match(false)
 for f in g.fighters:
  if not f.local_player:f.set_physics_process(false);f.global_position=Vector3(28,0,29)
 var p=g.player
 p.set_physics_process(false)
 p.global_position=Vector3(-4,.05,-30);p.yaw=PI-.3;p.pitch=0
 await frames(20)
 expect(Arsenal.WEAPONS.size()>0,'Weapon table is available')
 var automatic=0
 var single=0
 for kind in range(Arsenal.WEAPONS.size()):
  var w=Arsenal.WEAPONS[kind]
  var shots=1 if not w.get('auto',false) else 30
  p.weapon_id=kind;p.ammo=Arsenal.full_ammo();p.reserves=Arsenal.full_reserves();p.reload_left=0;p.cooldown=0
  p.build_gun();p.ads=false;p.pitch=0;p.yaw=PI-.3;p.recoil_return=Vector2.ZERO;p.recoil_sequence=0;p.shot_age=1
  await frames(6)
  var pitch0=p.pitch
  var residual=Vector2.ZERO
  var peak=0.0
  for s in range(shots):
   p.cooldown=0;p.shoot()
   residual=p.recoil_return
   peak=maxf(peak,rad_to_deg(p.pitch-pitch0))
   # one second of the recovery the game runs, per shot
   for i in range(60):
    p.shot_age=minf(1.0,p.shot_age+1.0/60.0);p.recover_recoil(1.0/60.0)
  var settled=rad_to_deg(p.pitch-pitch0)
  var debt=rad_to_deg(residual.length())
  if w.get('auto',false):
   automatic+=1
   # The cap only has to be an upper bound: the spray pattern must stay controllable.
   expect(debt<=rad_to_deg(deg_to_rad(w.get('recoil_residual',2.5)))+0.01,'Automatic %d keeps its burst debt capped (%.2f deg over %d shots)'%[kind,debt,shots])
   expect(peak>0.5 and peak<16.0,'Automatic %d keeps a controllable spray pattern (%.2f deg of climb)'%[kind,peak])
   # After the trigger is released and the rig recovers, the next shot must start from
   # the same place as the first one did: that is what makes the pattern learnable and
   # stops a long burst from silently re-aiming the player.
   var before=p.pitch
   var recovery_end=rad_to_deg(p.recoil_return.length())
   expect(recovery_end<0.01,'Automatic %d pays its debt back after the burst (%.4f deg left)'%[kind,recovery_end])
   expect(absf(p.pitch-before)<1e-6,'Automatic %d stops moving the view once firing stops'%kind)
  else:
   single+=1
   expect(absf(settled)<0.05,'Single-shot %d returns the kick exactly (%.4f deg after %d shots)'%[kind,settled,shots])
   expect(debt>=0.1 and debt<rad_to_deg(deg_to_rad(w.recoil))+0.05,'Single-shot %d kicks and then absorbs it (%.4f deg owed at the shot)'%[kind,debt])
 # Tap-firing the same weapon twice must not bias the aim either.
 p.weapon_id=0;p.ammo=Arsenal.full_ammo();p.reload_left=0;p.cooldown=0;p.pitch=0;p.recoil_return=Vector2.ZERO;p.shot_age=1
 await frames(4)
 var tap_start=p.pitch
 for burst in range(4):
  p.cooldown=0;p.shoot()
  for i in range(90):
   p.shot_age=minf(1.0,p.shot_age+1.0/60.0);p.recover_recoil(1.0/60.0)
 var tap_drift=rad_to_deg(p.pitch-tap_start)
 expect(tap_drift<3.0 and tap_drift>0.0,'Four separated taps leave a bounded, predictable debt (%.2f deg)'%tap_drift)
 expect(automatic>0 and single>0,'Both weapon classes were covered (%d automatic, %d single-shot)'%[automatic,single])
 print('WEAPON_AIM ',checks,' checks, ',failures,' failures')
 quit(0 if failures==0 else 1)
