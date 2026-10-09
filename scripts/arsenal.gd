class_name Arsenal
extends RefCounted
# Real-world firearms. Viewmodels: assets/viewmodels/vm_<model>.glb (tools/build_viewmodels.py).
const WEAPONS = [
 {'name':'M4A1','model':'ar','sound':'rifle','damage':30.0,'interval':0.075,'mag':30,'reserve':120,'reload':2.2,'recoil':.95,'spread':.010,'auto':true,'range':55.0},
 {'name':'MK18 CQBR','model':'carbine','sound':'smg','damage':27.0,'interval':.068,'mag':20,'reserve':140,'reload':2.0,'recoil':.8,'spread':.014,'auto':true,'range':32.0},
 {'name':'MOSIN 91/30 PU','model':'sniper','sound':'marksman','damage':120.0,'interval':1.15,'mag':5,'reserve':30,'reload':2.35,'recoil':3.2,'spread':.002,'auto':false,'range':200.0,'bolt':true},
 {'name':'WALTHER P38','model':'pistol','sound':'pistol','damage':34.0,'interval':.14,'mag':8,'reserve':40,'reload':1.25,'recoil':1.5,'spread':.013,'auto':false,'range':25.0}
]
const PRIMARIES=[0,1,2]
const SECONDARY=3
# Three perk tiers in the CoD4 tradition. Keys are what gameplay code checks (Fighter.perk()).
const PERKS=[
 [{'key':'sleight','name':'SLEIGHT OF HAND','text':'Reload 25% faster'},
  {'key':'scavenger','name':'SCAVENGER','text':'Each kill refills your reserve ammunition'}],
 [{'key':'stopping','name':'STOPPING POWER','text':'Bullet damage +20%'},
  {'key':'juggernaut','name':'JUGGERNAUT','text':'Health 125 instead of 100'}],
 [{'key':'lightweight','name':'LIGHTWEIGHT','text':'Move 10% faster'},
  {'key':'steady','name':'STEADY AIM','text':'Hip-fire spread −35%'},
  {'key':'flak','name':'FLAK JACKET','text':'Explosive damage −40%'}]
]
# Default loadouts; players edit their three slots in CREATE A CLASS (settings.classes).
const CLASSES=[
 {'name':'RIFLEMAN','primary':0,'perks':[0,0,1]},
 {'name':'BREACHER','primary':1,'perks':[1,0,0]},
 {'name':'SNIPER','primary':2,'perks':[0,1,2]}
]
const WEAPON_NOTES=['Standard-issue carbine. Controllable at any range.','Short-barrel CQB carbine. Fast handling indoors.','Bolt-action rifle with PU scope. One shot to the body.']
# A loadout is {'name','primary','perks':[tier1,tier2,tier3]}; anything malformed falls back to defaults.
static func sanitize(loadout, slot: int) -> Dictionary:
 var base: Dictionary=CLASSES[clampi(slot,0,2)].duplicate(true)
 if not loadout is Dictionary:return base
 var out={'name':String(loadout.get('name',base.name)).strip_edges().to_upper().left(16),'primary':int(loadout.get('primary',base.primary)),'perks':[]}
 if out.name=='':out.name=base.name
 if out.primary not in PRIMARIES:out.primary=base.primary
 var perks=loadout.get('perks',base.perks)
 for tier in range(3):
  var choice=int(perks[tier]) if perks is Array and perks.size()>tier else base.perks[tier]
  out.perks.append(clampi(choice,0,PERKS[tier].size()-1))
 return out
static func perk_keys(loadout: Dictionary) -> Array:
 var keys=[]
 for tier in range(3):keys.append(PERKS[tier][loadout.perks[tier]].key)
 return keys
static func perk_names(loadout: Dictionary) -> String:
 var names=[]
 for tier in range(3):names.append(PERKS[tier][loadout.perks[tier]].name)
 return ' · '.join(names)
static func full_ammo() -> Array:return WEAPONS.map(func(w):return w.mag)
static func full_reserves() -> Array:return WEAPONS.map(func(w):return w.reserve)
