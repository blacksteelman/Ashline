from pathlib import Path
source=(Path(__file__).resolve().parent/'model.py').read_text().split('# Blender Z up')[0]
exec(source)
reset();steel=mat('Cast turbine casing',(.11,.15,.145),.7,.56);rust=mat('Oxidized edges',(.19,.10,.06),.5,.8);dark=mat('Rubber and gaskets',(.03,.04,.035));concrete=mat('Machine foundation',(.19,.22,.20));brass=mat('Couplings',(.32,.23,.10),.7,.38);ochre=mat('Safety paint',(.43,.25,.045),.45,.65)
cube('Foundation',(0,0,.15),(3.5,3.6,.3),concrete,.04)
for x in [-1.2,1.2]:cube('Mounting saddle',(x,0,.48),(.35,2.6,.6),steel,.04)
cyl('Turbine housing',(0,0,1.58),1.22,2.45,steel,rot=(math.pi/2,0,0))
for y in [-1.25,1.25]:
 tube('End flange',(0,y,1.58),1.32,.98,.14,steel)
 for i in range(20):
  a=i*math.tau/20;cyl('Hex flange fastener',(math.cos(a)*1.19,y+.10,1.58+math.sin(a)*1.19),.045,.055,brass,rot=(math.pi/2,0,0))
for i in range(12):
 a=i*math.tau/12
 blade=cube('Rotor blade',(math.cos(a)*.57,1.23,1.58+math.sin(a)*.57),(.64,.09,.17),rust,.012);blade.rotation_euler.y=-a;blade.rotation_euler.z=.18
cyl('Rotor hub',(0,1.32,1.58),.24,.23,steel,rot=(math.pi/2,0,0))
for x in [-.95,.95]:
 cyl('Service pipe',(x,-.7,2.82),.105,1.5,steel)
 cyl('Valve coupling',(x,-.7,3.20),.15,.11,brass)
 tube('Valve wheel',(x,-.7,3.48),.23,.20,.045,rust)
 for i in range(4):cube('Valve spoke',(x,-.7,3.48),(.40,.025,.025),rust,.003,rot=(0,0,i*math.pi/4))
for y in [-.7,.3]:
 cube('Casing rib',(0,y,2.73),(1.75,.065,.09),steel,.009)
for x in [-1.5,1.5]:
 for y in [-1.6,1.6]:cyl('Anchor bolt',(x,y,.35),.055,.11,rust)
cube('Control box',(1.49,.3,1.48),(.46,.75,.87),steel,.035)
for i in range(4):cyl('Control button',(1.735,.10+i*.13,1.52),.023,.015,ochre,rot=(0,math.pi/2,0))
for i in range(7):cube('Heat exchanger vent',(1.739,.3,1.29+i*.035),(.013,.52,.008),dark,.002)
export('turbine.glb')
reset();metal=mat('Workshop steel',(.13,.17,.16),.55,.68);wood=mat('Oil stained bench top',(.18,.14,.09));dark=mat('Worn rubber',(.035,.045,.036));paper=mat('Blueprint paper',(.44,.49,.40));yellow=mat('Industrial yellow',(.38,.26,.05),.4,.7)
cube('Bench top',(0,0,.92),(2.2,.78,.11),wood,.012)
for x in [-.98,.98]:
 for y in [-.27,.27]:cube('Bench leg',(x,y,.44),(.065,.065,.88),metal,.009)
 cube('Bench crossbar',(x,0,.20),(.055,.65,.055),metal,.008)
for x in [-.8,-.2,.4]:
 cube('Tool drawer',(x,0,.70),(.51,.6,.26),metal,.012);cube('Drawer pull',(x,.315,.70),(.21,.035,.03),dark,.007)
cube('Bench vise',(.74,0,1.04),(.34,.23,.13),metal,.018)
for x in [.61,.87]:cube('Vise jaw',(x,0,1.12),(.04,.18,.08),dark,.004)
cyl('Vise handle',(.93,.02,1.06),.013,.18,metal,rot=(0,math.pi/2,0))
cube('Folded work sheet',(-.38,.04,.982),(.42,.3,.003),paper,.001)
for i in range(5):cube('Drawing line',(-.44+i*.045,.05,.985),(.002,.21,.001),metal,0)
for i in range(3):cyl('Loose coupling',(-.82+i*.13,.02,.995),.035,.04,yellow)
export('workbench.glb')
reset();paint=mat('Generator painted steel',(.12,.16,.13),.45,.66);metal=mat('Hardware',(.22,.26,.23),.8,.34);dark=mat('Insulation',(.025,.035,.03));copper=mat('Copper leads',(.25,.11,.055),.8,.4)
cube('Generator base',(0,0,.13),(1.3,.9,.26),paint,.025)
cube('Diesel casing',(0,0,.66),(1.06,.72,.82),paint,.045)
for x in [-.54,.54]:
 for z in [.44,.61,.78]:cube('Cooling grille',(x,0,z),(.008,.61,.025),dark,.002)
for y in [-.32,.32]:
 cyl('Carry frame',(-.69,y,.65),.035,1.0,metal);cyl('Carry frame',(.69,y,.65),.035,1.0,metal)
 cyl('Top handle',(0,y,1.17),.035,1.4,metal,rot=(0,math.pi/2,0))
cyl('Exhaust',(.35,-.20,1.22),.035,.5,dark)
for i in range(3):cyl('Connector',(-.35+i*.18,.37,.65),.055,.035,copper,rot=(math.pi/2,0,0))
export('generator.glb')
