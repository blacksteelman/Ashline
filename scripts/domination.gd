class_name Domination
extends Node3D
# Domination: three capture points. Standing alone in a zone turns it toward your team
# (faster with more players, frozen while contested); an enemy zone is first neutralised.
# Every SCORE_INTERVAL seconds each held zone scores one point. The host simulates, clients
# receive [owner, progress] per zone in the snapshot.
const RADIUS=4.2
const CAPTURE_SECONDS=7.0
const SCORE_INTERVAL=4.0
const SCORE_LIMIT=150
const TIME_LIMIT=600.0
const POINTS=[['A',Vector3(1.5,0,-22)],['B',Vector3(-1,0,0)],['C',Vector3(1.5,0,22)]]
const COLORS=[Color('#73c0c4'),Color('#dba477'),Color('#c9c9bd')]
var game: Node3D
var zones: Array=[] # {name, position, owner (-1 neutral), progress (-1 Aegis .. +1 Ember), node parts}
var score_clock=0.0

func _ready():
 for entry in POINTS:
  var zone={'name':entry[0],'position':entry[1],'owner':-1,'progress':0.0,'present':[0,0]}
  build_marker(zone);zones.append(zone)

func build_marker(zone: Dictionary):
 var root=Node3D.new();add_child(root);root.position=zone.position
 # Ground ring.
 var ring=MeshInstance3D.new();var torus=TorusMesh.new();torus.inner_radius=RADIUS-.12;torus.outer_radius=RADIUS;torus.rings=64;torus.ring_segments=6
 ring.mesh=torus;ring.scale=Vector3(1,.04,1);ring.position.y=.03;root.add_child(ring)
 var ring_material=StandardMaterial3D.new();ring_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ring_material.albedo_color=COLORS[2];ring_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ring_material.albedo_color.a=.55
 ring.material_override=ring_material;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 # Pole and banner.
 var pole=MeshInstance3D.new();var cylinder=CylinderMesh.new();cylinder.top_radius=.03;cylinder.bottom_radius=.04;cylinder.height=3.2;pole.mesh=cylinder;pole.position=Vector3(0,1.6,0);root.add_child(pole)
 var steel=StandardMaterial3D.new();steel.albedo_color=Color('#3b3f3d');steel.metallic=.7;steel.roughness=.45;pole.material_override=steel
 var banner=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2(.9,.55);banner.mesh=quad;banner.position=Vector3(.47,2.85,0);root.add_child(banner)
 var cloth=StandardMaterial3D.new();cloth.albedo_color=COLORS[2];cloth.cull_mode=BaseMaterial3D.CULL_DISABLED;cloth.roughness=.9;banner.material_override=cloth
 var letter=Label3D.new();letter.text=zone.name;letter.font_size=96;letter.pixel_size=.006;letter.position=Vector3(0,3.45,0);letter.billboard=BaseMaterial3D.BILLBOARD_ENABLED;letter.outline_size=12;letter.no_depth_test=false;root.add_child(letter)
 zone.ring=ring_material;zone.cloth=cloth;zone.banner=banner;zone.letter=letter

func inside(zone: Dictionary, f: Fighter) -> bool:
 var d=f.global_position-zone.position
 return not f.dead and Vector2(d.x,d.z).length()<RADIUS and absf(d.y)<2.5

func step(dt: float):
 for zone in zones:
  var present=[0,0]
  for f in game.fighters:
   if inside(zone,f):present[f.team]+=1
  zone.present=present
  var rate=dt/CAPTURE_SECONDS
  if present[0]>0 and present[1]==0:advance(zone,-1.0,rate*minf(present[0],3)*(1.0+.5*float(present[0]>1)))
  elif present[1]>0 and present[0]==0:advance(zone,1.0,rate*minf(present[1],3)*(1.0+.5*float(present[1]>1)))
  elif present[0]==0 and present[1]==0:
   # An abandoned partial capture drifts back to the holder.
   var rest=0.0 if zone.owner<0 else (-1.0 if zone.owner==0 else 1.0)
   zone.progress=move_toward(zone.progress,rest,rate*.5)
 score_clock+=dt
 if score_clock>=SCORE_INTERVAL:
  score_clock-=SCORE_INTERVAL
  for zone in zones:
   if zone.owner>=0:game.scores[zone.owner]+=1

func advance(zone: Dictionary, direction: float, amount: float):
 var before=zone.progress
 zone.progress=clampf(zone.progress+direction*amount,-1,1)
 var team=0 if direction<0 else 1
 # Crossing the middle neutralises the enemy's zone.
 if zone.owner==1-team and signf(zone.progress)!=signf(before) and signf(zone.progress)==direction:zone.owner=-1;game.zone_event(zone.name,-1,team)
 if absf(zone.progress)>=1.0 and zone.owner!=team:
  zone.owner=team;game.zone_event(zone.name,team,team)
  for f in game.fighters:
   if inside(zone,f) and f.team==team:f.capture_count+=1

func update_visuals(dt: float):
 for zone in zones:
  var c=COLORS[zone.owner] if zone.owner>=0 else COLORS[2]
  if zone.owner<0 and absf(zone.progress)>.02:c=COLORS[2].lerp(COLORS[0 if zone.progress<0 else 1],absf(zone.progress))
  zone.cloth.albedo_color=zone.cloth.albedo_color.lerp(c,1-exp(-dt*6))
  zone.ring.albedo_color=Color(c.r,c.g,c.b,.55)
  zone.letter.modulate=c
  zone.banner.rotation.y=sin(Time.get_ticks_msec()*.0013+zone.position.z)*.12

func pack() -> Array:
 var out=[]
 for zone in zones:out.append([zone.owner,zone.progress,zone.present])
 return out

func unpack(data: Array):
 for i in range(mini(data.size(),zones.size())):
  var previous=zones[i].owner
  zones[i].owner=data[i][0];zones[i].progress=data[i][1];zones[i].present=data[i][2]
  if previous!=zones[i].owner:game.zone_event(zones[i].name,zones[i].owner,zones[i].owner,false)

# Bots: the nearest zone their team does not hold, else the nearest held zone to defend.
func objective_for(f: Fighter) -> Vector3:
 var best=Vector3.INF;var best_d=INF
 for zone in zones:
  if zone.owner==f.team:continue
  var d=f.global_position.distance_to(zone.position)*(1.0 if zone.owner<0 else 1.15)
  if d<best_d:best_d=d;best=zone.position
 if best==Vector3.INF:best=zones.pick_random().position
 var jitter=Vector2.from_angle(randf()*TAU)*randf_range(0,RADIUS*.7)
 return best+Vector3(jitter.x,0,jitter.y)

func zone_at(f: Fighter):
 for zone in zones:
  if inside(zone,f):return zone
 return null
