extends SceneTree
class CueGame extends 'res://scripts/game.gd':
 var cues=[]
 func sound(key:String,_pos:Vector3,_local:bool=false,_volume:float=0) -> Node:
  cues.append(key);return null
var checks=0
var failures=0
func expect(ok:bool,label:String):
 checks+=1;print('PASS ' if ok else 'FAIL ',label)
 if not ok:failures+=1
func _initialize():call_deferred('run')
func run():
 var g=CueGame.new();root.add_child(g);g.start_match(false)
 g.set_process(false);g.set_physics_process(false)
 for f in g.fighters:f.set_process(false);f.set_physics_process(false)
 var p=g.player
 for kind in [0,1,2,3,4]:
  p.weapon_id=kind;p.build_gun();var rig=p.view
  p.ads=false;p.sprinting=false;p.reload_left=0;p.velocity=Vector3.ZERO
  rig.update(p,.35)
  expect(rig.action!='draw','Weapon %d draw finishes before the first ADS transition'%kind)
  rig.player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  rig.stop_action();rig.fire(kind);rig.player.advance(.04)
  expect(rig.player.current_animation_position>.01,'Weapon %d firing clip actually advances'%kind)
  rig.fire(kind)
  expect(rig.player.current_animation_position<.001,'Weapon %d repeated shot restarts its mechanical animation'%kind)
  p.ads=false;p.sprinting=false;p.reload_left=0
  rig.player.seek(0,true);rig.update(p,.025)
  expect(rig.player.current_animation_position>0,'Weapon %d rig evaluates its own animation before framing'%kind)
  for empty in [false,true]:
   p.ammo[kind]=0 if empty else 8
   var duration=p.reload_time(kind)
   p.reload_left=duration*.5;rig.update(p,0)
   p.reload_left=duration*.48;rig.update(p,.016)
   var native=rig.player.get_animation(rig.clips[rig.action]).length
   expect(absf(rig.player.current_animation_position-native*.52)<.001,'Weapon %d %s reload follows gameplay clock exactly'%[kind,'empty' if empty else 'tactical'])
  p.reload_left=0;rig.update(p,.016)
  expect(rig.action not in ['reload','reload_empty'],'Weapon %d reload completion returns to locomotion'%kind)
  for empty in [false,true]:
   g.cues.clear();p.ammo[kind]=0 if empty else 8
   for i in 100:
    p.reload_left=p.reload_time(kind)*(1-i/100.0);rig.update(p,p.reload_time(kind)/100.0)
   var expected=['mag_out','mag_in','bolt'] if empty and rig.clips.has('reload_empty') else ['mag_out','mag_in']
   expect(g.cues==expected,'Weapon %d %s reload sounds play once in handling order'%[kind,'empty' if empty else 'tactical'])
   p.reload_left=0;rig.update(p,0)
  p.ads=true
  for i in 30:rig.update(p,1.0/60)
  var steady=rig.ads_reference
  rig.fire(kind);rig.update(p,.025)
  expect(rig.ads_reference.is_equal_approx(steady),'Weapon %d ADS preserves its pre-shot alignment during recoil'%kind)
  var wb=p.camera.global_transform.affine_inverse()*p.gun.global_transform*rig.bone_in_root(rig.weapon_bone)*rig.cfg.frame
  var direction=(wb*rig.cfg.front-wb*rig.cfg.rear).normalized()
  var angle=direction.angle_to(Vector3.FORWARD)
  print('ADS_RECOIL ',kind,' angle=',angle)
  expect(angle>.0001 and angle<deg_to_rad(rig.cfg.get('ads_recoil_limit',4.0))+.015,'Weapon %d ADS shows bounded authored recoil'%kind)
  p.ads=false;p.sprinting=true;p.velocity=Vector3(0,0,-7.8);rig.update(p,.016)
  expect(rig.action=='' if not Arsenal.WEAPONS[kind].get('bolt',false) else rig.action in ['fire','fire_ads'],'Weapon %d sprint interrupts firing recovery while preserving bolt cycle'%kind)
  p.sprinting=false;p.velocity=Vector3.ZERO
 g.queue_free();g=null;p=null;await process_frame;await process_frame
 print('FP_ACTIONS ',checks,' checks, ',failures,' failures');quit(0 if failures==0 else 1)
