class_name Arsenal
extends RefCounted
# Weapons. First-person: ccransh CC-BY sets in assets/viewmodels/<fp.set>/ (scripts/fp_set_rig.gd).
# fp.frame: barrel frame relative to the weapon bone (x right, y up, z along the barrel, scene units),
# measured by tests/fp_sights.gd; fp.rear/front: sight line in that frame; fp.scale: scene -> metres;
# fp.eye: eye distance behind the rear sight in ADS (m); fp.muzzle: muzzle point in the frame.
const WEAPONS = [
 {'name':'ACR 6.8','model':'ar','sound':'rifle','damage':32.0,'interval':0.08,'mag':30,'reserve':120,'reload':2.2,'recoil':.9,'spread':.010,'auto':true,'range':60.0,'zoom':.62,
  'fp':{'set':'fp_acr','bone':'ACRRifle','fwd':'+z','up':'+y','scale':1.0,'cam_offset':Vector3(-0.06,0.035,0.05),'cam_rot':Vector3(3,-5,0),'fov':56.0,'fov_ads':55.0,'eye':.22,
   'frame':Transform3D(Basis(Vector3(-0.999597,-0.023106,0.016516),Vector3(-0.02815,0.883307,-0.467949),Vector3(0.003777,0.468225,0.883601)),Vector3(0.052309,0.187252,-0.245893)),
   'rear':Vector3(0.055,0.006,0.25),'front':Vector3(0.056,0.006,0.39),'muzzle':Vector3(0.061,-0.134,1.08),'ejector':Vector3(0.075,-0.09,0.25)}},
 {'name':'AK-74M','model':'ar','sound':'rifle','damage':31.0,'interval':0.1,'mag':30,'reserve':120,'reload':2.6,'recoil':1.1,'spread':.012,'auto':true,'range':55.0,'zoom':.72,
  'fp':{'set':'fp_ak74m','bone':'PBody','fwd':'+z','up':'+y','scale':0.346,'cam_offset':Vector3(-0.06,0.04,0.05),'cam_rot':Vector3(3,-4,0),'fov':60.0,'fov_ads':55.0,'eye':.36,
   'frame':Transform3D(Basis(Vector3(-0.499041,0.003247,0.054519),Vector3(-0.054606,-0.039306,-0.497492),Vector3(-0.001051,0.500469,-0.039426)),Vector3(0.040358,-0.265475,-0.100388)),
   'rear':Vector3(0.093,-0.110,0.715),'front':Vector3(0.108,-0.181,1.69),'muzzle':Vector3(0.107,-0.266,1.91),'ejector':Vector3(0.14,-0.2,0.2)}},
 {'name':'BOLT-ACTION .308','model':'sniper','sound':'marksman','damage':120.0,'interval':1.2,'mag':5,'reserve':30,'reload':3.0,'recoil':3.2,'spread':.002,'auto':false,'range':200.0,'bolt':true,'scope':true,'zoom':.32,'kick':1.6,
  'fp':{'set':'fp_sniper','bone':'Body','fwd':'-y','up':'+z','cam_offset':Vector3(-0.02,0.23,0.15),'cam_rot':Vector3(5,0,0),'scale':1.0,'fov':68.0,'fov_ads':55.0,'eye':.08,
   'frame':Transform3D(Basis(Vector3(-0.994791,-0.05109,0.088204),Vector3(-0.101897,0.52101,-0.847447),Vector3(0.002659,0.85202,0.523502)),Vector3(0.081174,-0.023836,0.054162)),
   'rear':Vector3(0.071,0.23,0.10),'front':Vector3(0.071,0.23,0.25),'muzzle':Vector3(0.10,0.105,0.71),'ejector':Vector3(0.11,0.15,0.05)}},
 {'name':'SPRINGFIELD XD','model':'pistol','sound':'pistol','damage':34.0,'interval':.13,'mag':13,'reserve':52,'reload':1.5,'recoil':1.4,'spread':.013,'auto':false,'range':25.0,'zoom':.8,'kick':1.2,
  'fp':{'set':'fp_pistol','bone':'PBody','fwd':'+z','up':'+y','scale':0.77,'cam_offset':Vector3(-0.05,0.03,0.04),'cam_rot':Vector3(2,-4,0),'fov':60.0,'fov_ads':58.0,'eye':.27,
   'frame':Transform3D(Basis(Vector3(-0.969282,-0.217632,0.114583),Vector3(-0.245938,0.86273,-0.441827),Vector3(0.002698,0.456435,0.889753)),Vector3(0.047616,0.158445,-0.401117)),
   'rear':Vector3(0.085,-0.137,0.30),'front':Vector3(0.093,-0.168,0.468),'ads_roll':14.0,'muzzle':Vector3(0.10,-0.20,0.48),'ejector':Vector3(0.115,-0.15,0.36)}},
 {'name':'MPA 30 SST','model':'carbine','sound':'smg','damage':25.0,'interval':.066,'mag':30,'reserve':150,'reload':2.3,'recoil':.75,'spread':.015,'auto':true,'range':30.0,'zoom':.75,
  'fp':{'set':'fp_smg','bone':'PBody','fwd':'+z','up':'+y','scale':0.5,'cam_offset':Vector3(-0.08,0.05,0.07),'cam_rot':Vector3(3,-4,0),'fov':58.0,'fov_ads':55.0,'eye':.14,
   'frame':Transform3D(Basis(Vector3(-0.501532,-0.053159,0.026236),Vector3(-0.058382,0.481693,-0.140044),Vector3(0.010283,0.142108,0.484508)),Vector3(0.03771,0.216937,-0.279836)),
   'rear':Vector3(0.098,-0.0935,0.2),'front':Vector3(0.0943,-0.268,0.795),'ads_roll':5.6,'muzzle':Vector3(0.146,-0.4245,1.13),'ejector':Vector3(0.14,-0.2,0.3)}},
]
const PRIMARIES=[0,1,4,2]
const SECONDARY=3
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
 {'name':'BREACHER','primary':4,'perks':[1,0,0]},
 {'name':'SNIPER','primary':2,'perks':[0,1,2]}
]
const WEAPON_NOTES=['Suppressed 6.8 mm rifle with a red-dot sight.','5.45 mm assault rifle. Hard-hitting, heavier recoil.','Scoped bolt-action rifle. One shot to the body.','Compact sidearm.','Suppressed 9 mm SMG. Fast handling indoors.']
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
static func scoped(kind: int) -> bool:return WEAPONS[kind].get('scope',false)
static func full_reserves() -> Array:return WEAPONS.map(func(w):return w.reserve)
