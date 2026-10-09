class_name Arsenal
extends RefCounted
# Real-world firearms. Viewmodels: assets/viewmodels/vm_<model>.glb (tools/build_viewmodels.py).
const WEAPONS = [
 {'name':'M4A1','model':'ar','sound':'rifle','damage':30.0,'interval':0.075,'mag':30,'reserve':120,'reload':2.2,'recoil':.95,'spread':.010,'auto':true,'range':55.0},
 {'name':'MK18 CQBR','model':'carbine','sound':'smg','damage':27.0,'interval':.068,'mag':20,'reserve':140,'reload':2.0,'recoil':.8,'spread':.014,'auto':true,'range':32.0},
 {'name':'MOSIN 91/30 PU','model':'sniper','sound':'marksman','damage':120.0,'interval':1.15,'mag':5,'reserve':30,'reload':2.35,'recoil':3.2,'spread':.002,'auto':false,'range':200.0,'bolt':true},
 {'name':'WALTHER P38','model':'pistol','sound':'pistol','damage':34.0,'interval':.14,'mag':8,'reserve':40,'reload':1.25,'recoil':1.5,'spread':.013,'auto':false,'range':25.0}
]
const CLASSES = [
 {'name':'RIFLEMAN','weapon':0,'perk':'SLEIGHT OF HAND','description':'M4A1 · Walther P38 · 2 × Frag\nSleight of Hand: reload 22% faster'},
 {'name':'BREACHER','weapon':1,'perk':'LIGHTWEIGHT','description':'Mk18 CQBR · Walther P38 · 2 × Frag\nLightweight: sprint 12% faster'},
 {'name':'SNIPER','weapon':2,'perk':'FLAK JACKET','description':'Mosin 91/30 PU · Walther P38 · 2 × Frag\nFlak Jacket: explosive damage −25%'}
]
static func full_ammo() -> Array:return WEAPONS.map(func(w):return w.mag)
static func full_reserves() -> Array:return WEAPONS.map(func(w):return w.reserve)
