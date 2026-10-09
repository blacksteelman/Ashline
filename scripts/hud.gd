extends Control
var game: Node3D
var font: Font=preload('res://assets/interface.ttf')
var mono: Font=preload('res://assets/mono.ttf')
var ivory=Color('#dedfce')
var muted=Color('#94abaa')
var teal=Color('#73c0c4')
var orange=Color('#dba477')
func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var minimap=load('res://scripts/minimap.gd').new();minimap.game=game;add_child(minimap)
func _process(_dt):queue_redraw()
func words(pos: Vector2, text: String, size_v: int=16, color: Color=Color('#dedfce'), fixed: bool=false):
 draw_string(mono if fixed else font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_v,Color(0,0,0,.8));draw_string(mono if fixed else font,pos+Vector2(0,-1),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_v,color)
func _draw():
 var sx=get_viewport_rect().size.x/1600.0;var sy=get_viewport_rect().size.y/900.0;draw_set_transform(Vector2.ZERO,0,Vector2(sx,sy))
 if game.menu_open:return
 if game.state not in ['match','results']:return
 var p=game.player
 var scoped=p and not p.dead and p.weapon_id==2 and p.ads and p.reload_left<=0 and p.view.aim_blend>.98
 if scoped:scope_overlay()
 draw_rect(Rect2(660,20,280,56),Color(.025,.04,.045,.65))
 words(Vector2(680,49),'AEGIS',12,teal);words(Vector2(851,49),'EMBER',12,orange)
 words(Vector2(741,62),str(game.scores[0]),25,ivory,true);words(Vector2(818,62),str(game.scores[1]),25,ivory,true)
 var seconds=maxi(0,int(game.time_left));words(Vector2(776,40),'%02d:%02d' % [seconds/60,seconds%60],12,ivory,true)
 words(Vector2(693,92),'TDM / '+str(game.score_limit)+'   ·   FOUNDRY',12,muted)
 for i in range(mini(game.feed.size(),5)):
  var f=game.feed[i];words(Vector2(1170,110+i*24),f.killer+'  '+('◇' if f.head else '›')+'  '+f.victim,14,teal if f.team==0 else orange)
 if not p:return
 # Minimap: scripts/minimap.gd (child control, clipped and rotating).
 if game.radar_time[p.team]>0:words(Vector2(28,212),'RECON  '+str(int(game.radar_time[p.team]))+'s',12,teal)
 if Input.is_action_pressed('scoreboard'):
  scoreboard();return
 if p.dead:
  draw_rect(Rect2(0,0,1600,900),Color(.08,.02,.018,.24));words(Vector2(630,390),'KILLED IN ACTION',29,ivory);words(Vector2(671,427),'DEPLOYING IN %.1f' % maxf(0,p.respawn_time),17,muted);return
 var c=Vector2(800,450)
 if not p.ads:
  var gap=5+p.kick*90+(3 if p.move_wish.length()>.1 else 0)
  for d in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:draw_line(c+d*gap,c+d*(gap+5),Color(1,1,.9,.7),1)
 elif not scoped:draw_circle(c,1,Color(1,1,.9,.65))
 if game.hit_time>0:
  var col=orange if game.head_time>0 or game.kill_time>0 else ivory
  for x in [-1,1]:
   for y in [-1,1]:draw_line(c+Vector2(x,y)*6,c+Vector2(x,y)*12,col,2)
 if game.kill_time>0:words(Vector2(727,504),'+100 / '+('HEADSHOT' if game.kill_zone=='HEAD' else 'CONFIRMED'),15,ivory,true)
 if game.damage_flash>0:
  var red=Color(.6,.06,.025,game.damage_flash*.36);draw_rect(Rect2(0,0,1600,30),red);draw_rect(Rect2(0,870,1600,30),red);draw_rect(Rect2(0,0,30,900),red);draw_rect(Rect2(1570,0,30,900),red)
 words(Vector2(1290,824),'%02d' % p.ammo[p.weapon_id],38,ivory,true);words(Vector2(1361,821),'/ %03d' % p.reserves[p.weapon_id],20,muted,true)
 words(Vector2(1290,851),Arsenal.WEAPONS[p.weapon_id].name,13,muted)
 words(Vector2(1290,875),'G  '+str(p.grenades)+' FRAG',11,muted,true)
 if p.reload_left>0:words(Vector2(730,564),'RELOADING',14,ivory)
 elif p.ammo[p.weapon_id]<6:words(Vector2(729,564),'R  /  RELOAD',14,orange)
 words(Vector2(36,839),Arsenal.CLASSES[p.class_id].name+' / '+Arsenal.CLASSES[p.class_id].perk,13,muted)
 draw_rect(Rect2(36,855,100,3),Color(.2,.25,.25));draw_rect(Rect2(36,855,p.health,3),teal if p.health>35 else orange)
 words(Vector2(146,862),str(int(p.health)),13,muted,true)
 words(Vector2(36,886),'STREAK  '+str(p.streak)+'  /  '+('3 RECON' if p.streak<3 else ('5 MORTAR' if p.streak<5 else '7 OVERWATCH')),11,muted,true)
 if not p.rewards.is_empty():words(Vector2(620,770),'3  /  '+{3:'RECON',5:'MORTAR',7:'OVERWATCH'}[p.rewards[0]]+' AVAILABLE',18,teal)

func scoreboard():
 draw_rect(Rect2(390,165,820,550),Color(.025,.045,.05,.94));words(Vector2(425,207),'FOUNDRY / TEAM DEATHMATCH',25,ivory)
 words(Vector2(425,245),'CALLSIGN                     TEAM          K     D     STREAK',14,muted,true)
 var ordered=game.fighters.duplicate();ordered.sort_custom(func(a,b):return a.team<b.team if a.team!=b.team else a.kills>b.kills)
 for i in range(ordered.size()):
  var f=ordered[i];var y=280+i*32
  if f.local_player:draw_rect(Rect2(413,y-22,775,29),Color(.17,.27,.28,.6))
  words(Vector2(425,y),'%-28s %-10s   %3d   %3d   %3d' % [game.callsign(f),'AEGIS' if f.team==0 else 'EMBER',f.kills,f.deaths,f.streak],15,teal if f.team==0 else orange,true)

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
