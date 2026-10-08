class_name Arsenal
extends RefCounted
const WEAPONS = [
 {'name':'AR-41 / ASSAULT','sound':'rifle','damage':34.0,'interval':0.092,'mag':30,'reserve':120,'reload':1.65,'recoil':1.1,'spread':.011,'auto':true},
 {'name':'KITE-9 / SMG','sound':'smg','damage':26.0,'interval':.068,'mag':36,'reserve':144,'reload':1.4,'recoil':.75,'spread':.015,'auto':true},
 {'name':'MR-62 / MARKSMAN','sound':'marksman','damage':59.0,'interval':.29,'mag':14,'reserve':56,'reload':2.05,'recoil':2.3,'spread':.005,'auto':false},
 {'name':'P-12 / SIDEARM','sound':'pistol','damage':32.0,'interval':.18,'mag':12,'reserve':48,'reload':1.15,'recoil':1.4,'spread':.013,'auto':false}
]
const CLASSES = [
 {'name':'RIFLEMAN','weapon':0,'perk':'SLEIGHT','description':'AR-41 · P-12 · Frag\nSleight: reload 22% faster'},
 {'name':'RAIDER','weapon':1,'perk':'MOBILITY','description':'KITE-9 · P-12 · Frag\nMobility: sprint 12% faster'},
 {'name':'WATCHMAN','weapon':2,'perk':'RESILIENCE','description':'MR-62 · P-12 · Frag\nResilience: explosive damage −25%'}
]
