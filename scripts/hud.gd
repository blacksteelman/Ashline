extends Control
var game: Node3D
var font: Font=preload('res://assets/interface.ttf')
var mono: Font=preload('res://assets/mono.ttf')
var ivory=Color('#dedfce')
var muted=Color('#b5c3bd')
var teal=Color('#73c0c4')
var orange=Color('#dba477')
func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var minimap=load('res://scripts/minimap.gd').new();minimap.game=game;add_child(minimap)
func _process(_dt):queue_redraw()
func words(pos: Vector2, text: String, size_v: int=16, color: Color=Color('#dedfce'), fixed: bool=false):
 var face=mono if fixed else font
 draw_string_outline(face,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_v,2,Color(0,0,0,.8))
 draw_string(face,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_v,color)
func _draw():
 var sx=get_viewport_rect().size.x/1600.0;var sy=get_viewport_rect().size.y/900.0;draw_set_transform(Vector2.ZERO,0,Vector2(sx,sy))
 if game.menu_open:return
 if game.state not in ['match','results']:return
 var p=game.player
 var scoped=p and not p.dead and Arsenal.scoped(p.weapon_id) and p.ads and p.reload_left<=0 and p.view.aim_blend>.98
 if scoped:scope_overlay()
 # Score panel (CoD-style: team, score, clock), readable at 720p.
 draw_rect(Rect2(620,16,360,70),Color(.025,.04,.045,.7));draw_rect(Rect2(620,16,180,3),teal);draw_rect(Rect2(800,16,180,3),orange)
 words(Vector2(636,46),'AEGIS',17,teal);words(Vector2(902,46),'EMBER',17,orange)
 words(Vector2(712,74),'%3d' % game.scores[0],34,ivory,true);words(Vector2(822,74),'%-3d' % game.scores[1],34,ivory,true)
 var seconds=maxi(0,int(game.time_left));words(Vector2(768,44),'%02d:%02d' % [seconds/60,seconds%60],18,ivory,true)
 draw_rect(Rect2(620,86,360,28),Color(.025,.04,.045,.7))
 words(Vector2(636,106),('DOMINATION / ' if game.mode=='dom' else 'TEAM DEATHMATCH / ')+str(game.score_limit)+'   ·   FOUNDRY',15,muted)
 if game.domination:zones_overlay()
 for i in range(mini(game.feed.size(),5)):
  var f=game.feed[i];var y=130+i*30
  var line=('◆  '+f.killer) if f.get('event',false) else (f.killer+'  '+('◇' if f.head else '›')+'  '+f.victim)
  var w=font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
  draw_rect(Rect2(1572-w-14,y-21,w+20,28),Color(.02,.03,.035,.55))
  words(Vector2(1572-w,y),line,18,teal if f.team==0 else orange)
 if not p:return
 # Minimap: scripts/minimap.gd (child control, clipped and rotating).
 if game.radar_time[p.team]>0:words(Vector2(28,232),'RECON  '+str(int(game.radar_time[p.team]))+'s',16,teal)
 if Input.is_action_pressed('scoreboard'):
  scoreboard();return
 if p.dead:
  draw_rect(Rect2(0,0,1600,900),Color(.08,.02,.018,.24));words(Vector2(600,390),'KILLED IN ACTION',38,ivory);words(Vector2(660,432),'DEPLOYING IN %.1f' % maxf(0,p.respawn_time),22,muted);return
 var c=Vector2(800,450)
 if not p.ads:
  var gap=7+p.kick*110+(5 if p.move_wish.length()>.1 else 0)+(10 if p.sprinting else 0)
  for d in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
   draw_line(c+d*gap,c+d*(gap+9),Color(0,0,0,.55),4);draw_line(c+d*gap,c+d*(gap+9),Color(1,1,.92,.85),2)
 elif not scoped:draw_circle(c,1.5,Color(1,1,.9,.7))
 if game.hit_time>0:
  var col=orange if game.head_time>0 or game.kill_time>0 else ivory
  for x in [-1,1]:
   for y in [-1,1]:draw_line(c+Vector2(x,y)*7,c+Vector2(x,y)*16,col,3)
 if game.kill_time>0:words(Vector2(712,512),'+100  '+('HEADSHOT' if game.kill_zone=='HEAD' else 'KILL'),22,orange if game.kill_zone=='HEAD' else ivory,true)
 if game.damage_flash>0:
  var red=Color(.6,.06,.025,game.damage_flash*.42);draw_rect(Rect2(0,0,1600,40),red);draw_rect(Rect2(0,860,1600,40),red);draw_rect(Rect2(0,0,40,900),red);draw_rect(Rect2(1560,0,40,900),red)
 # Compact ammo block: numerical counts and a thin capacity bar.
 var mag=Arsenal.WEAPONS[p.weapon_id].mag;var left=p.ammo[p.weapon_id]
 draw_rect(Rect2(1270,794,310,88),Color(.02,.03,.035,.65))
 words(Vector2(1288,838),'%02d' % left,42,ivory if left>=mag*.25 else orange,true);words(Vector2(1370,836),'/ %03d' % p.reserves[p.weapon_id],24,muted,true)
 draw_rect(Rect2(1288,846,270,3),Color(.3,.34,.34,.6))
 draw_rect(Rect2(1288,846,270*clampf(float(left)/mag,0,1),3),ivory if left>=mag*.25 else orange)
 words(Vector2(1288,874),Arsenal.WEAPONS[p.weapon_id].name,18,muted)
 words(Vector2(1470,874),'G  '+str(p.grenades),18,ivory if p.grenades>0 else muted,true)
 if p.reload_left>0:words(Vector2(730,580),'RELOADING',20,ivory)
 elif left<maxi(3,mag/5):words(Vector2(712,580),'[R]  RELOAD',20,orange)
 # Health, class and streak.
 draw_rect(Rect2(24,784,520,98),Color(.02,.03,.035,.65))
 words(Vector2(40,807),p.loadout.get('name',''),15,ivory)
 var perks=Arsenal.perk_names(p.loadout)
 var perk_size=mini(15,int(480.0/maxf(1,font.get_string_size(perks,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x)*15))
 words(Vector2(40,828),perks,perk_size,muted)
 draw_rect(Rect2(40,838,240,8),Color(.2,.25,.25));draw_rect(Rect2(40,838,p.health/p.max_health*240,8),teal if p.health>35 else orange)
 words(Vector2(292,848),str(int(p.health)),18,ivory,true)
 words(Vector2(40,872),'STREAK '+str(p.streak)+'  ›  '+('3 RECON' if p.streak<3 else ('5 MORTAR' if p.streak<5 else '7 OVERWATCH')),15,muted,true)
 if not p.rewards.is_empty():words(Vector2(590,760),'[3]  '+{3:'RECON',5:'MORTAR',7:'OVERWATCH'}[p.rewards[0]]+' READY',24,teal)

# Domination: A/B/C under the score panel and a capture bar while standing in a zone.
func zones_overlay():
 var p=game.player
 for i in range(game.domination.zones.size()):
  var zone=game.domination.zones[i];var pos=Vector2(730+i*50,122)
  var c=Domination.COLORS[zone.owner] if zone.owner>=0 else Color(.55,.58,.56)
  draw_rect(Rect2(pos,Vector2(42,32)),Color(.025,.04,.045,.75));draw_rect(Rect2(pos,Vector2(42,32)),c,false,2)
  if zone.owner<0 and absf(zone.progress)>.02:draw_rect(Rect2(pos+Vector2(2,27),Vector2(38*absf(zone.progress),3)),Domination.COLORS[0 if zone.progress<0 else 1])
  words(pos+Vector2(13,24),zone.name,19,c)
 if not p or p.dead:return
 var zone=game.domination.zone_at(p)
 if zone==null:return
 var mine=-1.0 if p.team==0 else 1.0
 var share=clampf((zone.progress*mine+1.0)*.5,0,1)
 var contested=zone.present[0]>0 and zone.present[1]>0
 var title='CONTESTED  '+zone.name if contested else ('HOLDING  '+zone.name if zone.owner==p.team else 'CAPTURING  '+zone.name)
 words(Vector2(720,618),title,20,ivory)
 draw_rect(Rect2(680,630,240,8),Color(.02,.03,.03,.8));draw_rect(Rect2(680,630,240*share,8),teal if p.team==0 else orange)
func scoreboard():
 draw_rect(Rect2(390,165,820,550),Color(.025,.045,.05,.94));words(Vector2(425,207),'FOUNDRY / '+('DOMINATION' if game.mode=='dom' else 'TEAM DEATHMATCH'),28,ivory)
 words(Vector2(425,245),'CALLSIGN                     TEAM          K     D     STREAK',16,muted,true)
 var ordered=game.fighters.duplicate();ordered.sort_custom(func(a,b):return a.team<b.team if a.team!=b.team else a.kills>b.kills)
 for i in range(ordered.size()):
  var f=ordered[i];var y=280+i*32
  if f.local_player:draw_rect(Rect2(413,y-22,775,29),Color(.17,.27,.28,.6))
  words(Vector2(425,y),'%-28s %-10s   %3d   %3d   %3d' % [game.callsign(f),'AEGIS' if f.team==0 else 'EMBER',f.kills,f.deaths,f.streak],17,teal if f.team==0 else orange,true)

func scope_overlay():
 var center=Vector2(800,450);var radius=332.0
 for i in range(96):
  var a=Vector2.from_angle(i*TAU/96);var b=Vector2.from_angle((i+1)*TAU/96)
  draw_colored_polygon(PackedVector2Array([center+a*radius,center+b*radius,center+b*2000,center+a*2000]),Color(.012,.016,.017,.98))
 draw_arc(center,radius,0,TAU,128,Color('#182124'),7,true)
 for d in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
  draw_line(center+d*6,center+d*radius,Color(.015,.018,.016,.9),1,true)
  draw_line(center+d*(radius*.7),center+d*radius,Color(.015,.018,.016,.9),3,true)
 for i in range(1,6):
  var y=450+i*31;draw_line(Vector2(794,y),Vector2(806,y),Color(.015,.018,.016,.9),1,true)
 draw_circle(center,1.3,Color('#bca582'))
