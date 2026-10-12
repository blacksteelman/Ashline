extends SceneTree
# Aim-down-sights sensitivity: with a 3x scope the player must not have to fight the
# sights, so the mouse turns less of the view while scoped, by the zoom in use.
# The rule lives in Fighter.turn_scale(), so this checks that one function: a headless
# window can never report MOUSE_MODE_CAPTURED, so driving _input here would only prove
# that the engine blocks synthetic look input.
var checks=0
var failures=0
func expect(ok: bool, label: String):
 checks+=1
 print('PASS ' if ok else 'FAIL ',label)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
 var base=90.0
 expect(Fighter.turn_scale(base,base,true)==1.0,'An unscoped weapon keeps the hip-fire turn')
 var sniper=Fighter.turn_scale(28.8,base,true)
 expect(absf(sniper-28.8/90.0)<1e-4,'The sniper zoom scales the turn by the zoom in use (%.3f)'%sniper)
 expect(sniper<0.35,'A 3x scope turns at most a third as fast (%.3f)'%sniper)
 for entry in [[62.0,0.62],[55.0,0.55],[29.0,0.29]]:
  var scale=Fighter.turn_scale(entry[0],100.0,true)
  expect(absf(scale-entry[1])<1e-4,'Scale follows the field of view exactly (%.2f -> %.2f)'%[entry[0],scale])
 expect(Fighter.turn_scale(28.8,base,false)==1.0,'The option turns the scaling off')
 expect(Fighter.turn_scale(0.0,base,true)>0.0 and Fighter.turn_scale(0.0,base,true)<0.1,'A degenerate field of view cannot zero the turn')
 # The game must actually use it, with the option on by default.
 var g=load('res://main.tscn').instantiate();root.add_child(g)
 expect(g.settings.get('ads_sensitivity',false)==true,'ADS sensitivity scaling is on by default')
 g.settings.mode='tdm';g.settings.classes=[];g.settings.showcase=true
 g.start_match(false)
 for f in g.fighters:
  if not f.local_player:f.set_physics_process(false);f.global_position=Vector3(28,0,29)
 var p=g.player
 # Drive the presentation step by hand: with the engine also calling it, the zoom would
 # race this check.
 p.set_process(false);p.set_physics_process(false)
 p.weapon_id=2;p.ads=true;p.ammo=Arsenal.full_ammo();p.reload_left=0;p.sprinting=false;p.build_gun()
 var deadline=Time.get_ticks_msec()+2000
 while Time.get_ticks_msec()<deadline and p.camera.fov>g.settings.fov*0.4:
  p._process(1.0/60.0)
  await process_frame
 expect(p.camera.fov<g.settings.fov*0.4,'A scoped player is looking through the zoomed field of view (%.1f deg)'%p.camera.fov)
 var scale=Fighter.turn_scale(p.camera.fov,g.settings.fov,true)
 expect(scale<0.4,'That same zoom slows the mouse turn (%.3f of hip fire)'%scale)
 print('WEAPON_SENSITIVITY ',checks,' checks, ',failures,' failures')
 quit(0 if failures==0 else 1)
