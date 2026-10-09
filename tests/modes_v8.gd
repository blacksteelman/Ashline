extends SceneTree
# Perks, create-a-class sanitising and Domination capture rules.
# godot --headless --path . --script tests/modes_v8.gd
var checks=0
var failures=0
func expect(ok: bool, message: String):
 if ok:checks+=1;print('PASS: ',message)
 else:failures+=1;push_error('FAIL: '+message)
func _initialize():call_deferred('run')
func run():
 # Loadouts.
 var bad=Arsenal.sanitize({'name':'  my class with a very long name ','primary':3,'perks':[9,-4]},1)
 expect(bad.primary==Arsenal.CLASSES[1].primary and bad.perks.size()==3 and bad.perks[0]==Arsenal.PERKS[0].size()-1 and bad.perks[1]==0,'Malformed loadouts are clamped to valid choices')
 expect(bad.name.length()<=16 and bad.name==bad.name.to_upper(),'Class names are trimmed and upper-cased')
 expect(Arsenal.sanitize(null,2)==Arsenal.CLASSES[2],'Missing loadout falls back to the default slot')
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.settings.mode='dom';g.start_match(false);g.showcase=true
 for f in g.fighters:f.set_physics_process(false);f.set_process(false)
 g.set_physics_process(false)
 var p: Fighter=g.player
 p.set_loadout({'name':'TEST','primary':0,'perks':[0,1,0]})
 expect(is_equal_approx(p.reload_time(0),Arsenal.WEAPONS[0].reload*.75),'Sleight of Hand shortens reloads')
 expect(p.max_health==125.0,'Juggernaut raises health to 125')
 p.set_loadout({'name':'TEST','primary':0,'perks':[1,0,2]})
 expect(p.perk('scavenger') and p.perk('stopping') and p.perk('flak') and p.max_health==100.0,'Perk keys follow the chosen tiers')
 g.save_class(1,{'name':'Shotgun','primary':2,'perks':[1,1,1]})
 expect(g.class_loadout(1).name=='SHOTGUN' and g.class_loadout(1).primary==2,'Edited class is stored and read back')
 g.settings.classes=[];g.save_settings()
 # Domination.
 expect(g.mode=='dom' and g.domination!=null and g.domination.zones.size()==3,'Domination match creates zones A, B and C')
 expect(g.score_limit==Domination.SCORE_LIMIT and is_equal_approx(g.time_left,Domination.TIME_LIMIT),'Domination uses its own limits')
 var d: Domination=g.domination
 for f in g.fighters:f.global_position=Vector3(40,0,40)+Vector3(f.id,0,0)
 var a: Fighter=g.fighters[0];var b: Fighter=g.fighters[6]
 a.global_position=d.zones[1].position+Vector3(1,0,0)
 for i in range(int(Domination.CAPTURE_SECONDS*60)+5):d.step(1.0/60)
 expect(d.zones[1].owner==0,'One Aegis soldier captures B in the capture time')
 for i in range(int(Domination.SCORE_INTERVAL*60)+2):d.step(1.0/60)
 expect(g.scores[0]>0,'A held zone scores over time')
 b.global_position=d.zones[1].position+Vector3(-1,0,0)
 var before=d.zones[1].progress
 for i in range(120):d.step(1.0/60)
 expect(is_equal_approx(d.zones[1].progress,before) and d.zones[1].owner==0,'Contested zone does not change')
 a.global_position=Vector3(50,0,50)
 for i in range(int(Domination.CAPTURE_SECONDS*60*1.05)):d.step(1.0/60)
 expect(d.zones[1].owner==-1,'Enemy first neutralises the zone')
 for i in range(int(Domination.CAPTURE_SECONDS*60*1.05)):d.step(1.0/60)
 expect(d.zones[1].owner==1,'Then captures it for Ember')
 var kills=g.scores.duplicate();g.confirm_kill(a,b,'TORSO')
 expect(g.scores==kills,'Kills do not score in Domination')
 var packed=d.pack();d.zones[1].owner=0;d.unpack(packed)
 expect(d.zones[1].owner==1,'Zone state round-trips through the snapshot')
 g.settings.mode='tdm';g.save_settings();g.start_match(false)
 expect(g.domination==null and g.score_limit==75,'Team Deathmatch removes the zones')
 print('MODES_V8 ',checks,' passed, ',failures,' failed')
 quit(1 if failures else 0)
