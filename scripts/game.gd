extends Node3D
var arena: Arena
var world_environment: Environment
var fighters: Array[Fighter]=[]
var player: Fighter
var state='menu'
var menu_open=false
var settings={'sensitivity':1.5,'fov':90.0,'volume':.75,'fullscreen':false,'graphics':1,'vsync':true}
var hud: CanvasLayer
var ui: Control
var scores=[0,0]
var time_left=420.0
var score_limit=75
var match_number=0
var feed: Array=[]
var hit_time=0.0
var head_time=0.0
var kill_zone='TORSO'
var kill_time=0.0
var damage_flash=0.0
var radar_time=[0.0,0.0]
var fx: Array=[]
var grenades: Array=[]
var bot_test=false
var test_seed=0
var test_matches=0
var test_goal=3
var test_elapsed=0.0
var test_shots=0
var test_headshots=0
var test_recoveries: Array=[]
var menu_camera: Camera3D
var net_mode='offline'
var dedicated_server=false
var net_test_age=0.0
var local_id=0
var net_timer=0.0
var snapshot_count=0
var showcase=false
var capture_at=0.0
var capture_path='user://capture.png'
var sound_cache: Dictionary={}
var address_field: LineEdit
var selected_class=0
func _ready():
 configure_input();configure_network();AudioMix.configure();load_settings()
 if OS.has_feature('editor'):capture_path='res://build/capture.png'
 arena=Arena.new();add_child(arena)
 var env=WorldEnvironment.new();var e=Environment.new();env.environment=e;world_environment=e;add_child(env)
 e.background_mode=Environment.BG_SKY
 var sky=Sky.new();var sky_mat=ProceduralSkyMaterial.new();sky_mat.sky_top_color=Color('#253e50');sky_mat.sky_horizon_color=Color('#95b0bc');sky_mat.ground_bottom_color=Color('#222b32');sky_mat.ground_horizon_color=Color('#a9aaa0');sky_mat.sun_angle_max=12;var atmosphere=ShaderMaterial.new();atmosphere.shader=load('res://assets/industrial_sky.gdshader');sky.sky_material=atmosphere;e.sky=sky
 e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color('#a6bdcb');e.ambient_light_energy=.32;e.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 if RenderingServer.get_current_rendering_method()=='forward_plus':
  e.ssao_enabled=true;e.ssao_radius=1.2;e.ssao_intensity=1.5;e.ssao_power=1.4
  e.ssil_radius=3;e.ssil_intensity=.6
  e.tonemap_mode=Environment.TONE_MAPPER_ACES
 apply_graphics()
 e.fog_enabled=true;e.fog_light_color=Color('#889795');e.fog_density=.0012;e.fog_sky_affect=.20
 var sun=DirectionalLight3D.new();add_child(sun);sun.rotation_degrees=Vector3(-36,-38,0);sun.light_color=Color('#ffe3bd');sun.light_energy=1.15;sun.shadow_enabled=true;sun.directional_shadow_max_distance=85
 menu_camera=Camera3D.new();add_child(menu_camera);menu_camera.position=Vector3(29,14,28);menu_camera.look_at(Vector3(0,2,0));menu_camera.current=true
 hud=CanvasLayer.new();hud.layer=5;add_child(hud)
 var overlay=load('res://scripts/hud.gd').new();overlay.game=self;hud.add_child(overlay)
 ui=Control.new();hud.add_child(ui)
 resize_ui();get_viewport().size_changed.connect(resize_ui)
 for name in ['rifle','smg','marksman','pistol','reload','step','hit','kill','explosion','ambient','mag_out','mag_in','bolt','impact_metal','impact_concrete','ricochet','step_concrete','step_metal','dryfire','impact_body']:sound_cache[name]=load('res://assets/'+name+'.wav')
 sound_cache['ambient'].loop_mode=AudioStreamWAV.LOOP_FORWARD
 sound('ambient',Vector3.ZERO,true,-14)
 var args=OS.get_cmdline_user_args()
 bot_test='--bot-test' in args;showcase='--showcase' in args
 for a in args:
  if a.begins_with('--seed='):test_seed=int(a.split('=')[1])
  if a.begins_with('--matches='):test_goal=int(a.split('=')[1])
  if a.begins_with('--capture='):capture_at=float(a.split('=')[1])
  if a.begins_with('--capture-path='):capture_path=a.substr(15)
 if '--net-test' in args:
  start_client('127.0.0.1')
 elif '--server' in args:
  start_host(true)
 elif bot_test:
  seed(test_seed);score_limit=40;Engine.time_scale=4;Engine.max_physics_steps_per_frame=64;start_match(true)
 elif showcase:
  start_match(false);player.global_position=Vector3(0,.2,-15);player.yaw=PI-.16
 else:main_menu()
func resize_ui():
 ui.scale=get_viewport().get_visible_rect().size/Vector2(1600,900)
 ui.size=Vector2(1600,900)
func configure_network():
 multiplayer.peer_connected.connect(peer_joined);multiplayer.peer_disconnected.connect(peer_left)
 multiplayer.connected_to_server.connect(server_connected)
 multiplayer.connection_failed.connect(connection_failed)
 multiplayer.server_disconnected.connect(server_disconnected)
func server_connected():
 if net_mode=='client':request_slot.rpc_id(1,selected_class)
func connection_failed():
 if net_mode=='client':leave_match();show_error('Connection failed')
func server_disconnected():
 if net_mode=='client':leave_match();show_error('Server disconnected')
func authority() -> bool:return net_mode!='client'
func configure_input():
 var keys={'forward':KEY_W,'back':KEY_S,'left':KEY_A,'right':KEY_D,'sprint':KEY_SHIFT,'crouch':KEY_CTRL,'jump':KEY_SPACE,'reload':KEY_R,'switch':KEY_Q,'grenade':KEY_G,'streak':KEY_3,'scoreboard':KEY_TAB,'escape':KEY_ESCAPE}
 for a in keys:
  InputMap.add_action(a);var ev=InputEventKey.new();ev.physical_keycode=keys[a];InputMap.action_add_event(a,ev)
 for a in ['fire','ads']:
  InputMap.add_action(a);var ev=InputEventMouseButton.new();ev.button_index=MOUSE_BUTTON_LEFT if a=='fire' else MOUSE_BUTTON_RIGHT;InputMap.action_add_event(a,ev)
func load_settings():
 var cfg=ConfigFile.new()
 if cfg.load('user://settings.cfg')==OK:
  for key in settings:settings[key]=cfg.get_value('game',key,settings[key])
 apply_settings()
func apply_graphics():
 if not world_environment:return
 var modern=RenderingServer.get_current_rendering_method()=='forward_plus'
 world_environment.ssao_enabled=modern and settings.graphics>0
 world_environment.ssil_enabled=modern and settings.graphics==2
 world_environment.ssr_enabled=modern and settings.graphics==2
 get_viewport().msaa_3d=Viewport.MSAA_DISABLED if settings.graphics==0 else Viewport.MSAA_4X
func apply_settings():
 apply_graphics()
 AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.001,settings.volume)))
 if DisplayServer.get_name()!='headless':
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
  DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
func save_settings():
 var cfg=ConfigFile.new()
 for key in settings:cfg.set_value('game',key,settings[key])
 cfg.save('user://settings.cfg');apply_settings()
func clear_ui():
 for child in ui.get_children():
  ui.remove_child(child);child.queue_free()
func panel(pos: Vector2, size_v: Vector2) -> VBoxContainer:
 var p=PanelContainer.new();ui.add_child(p);p.position=pos;p.size=size_v
 var s=StyleBoxFlat.new();s.bg_color=Color(.035,.055,.062,.95);s.border_color=Color('#536b6b');s.border_width_top=2;s.content_margin_left=30;s.content_margin_right=30;s.content_margin_top=25;s.content_margin_bottom=25;p.add_theme_stylebox_override('panel',s)
 var v=VBoxContainer.new();p.add_child(v);v.add_theme_constant_override('separation',14);return v
func label(v: Node, words: String, size_v: int=18, color: Color=Color('#bdc9c8')) -> Label:
 var l=Label.new();l.text=words;l.add_theme_font_override('font',load('res://assets/interface.ttf'));l.add_theme_font_size_override('font_size',size_v);l.add_theme_color_override('font_color',color);v.add_child(l);return l
func button(v: Node, words: String, action: Callable):
 var b=Button.new();b.text=words;b.custom_minimum_size=Vector2(0,48);b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.add_theme_font_override('font',load('res://assets/interface.ttf'));b.add_theme_font_size_override('font_size',18)
 var s=StyleBoxFlat.new();s.bg_color=Color(.065,.09,.095,.85);s.content_margin_left=18;s.border_width_bottom=1;s.border_color=Color('#33474a');b.add_theme_stylebox_override('normal',s)
 var h=s.duplicate();h.bg_color=Color('#2b3d3e');h.border_width_left=3;h.border_color=Color('#a9c9bd');b.add_theme_stylebox_override('hover',h);b.add_theme_stylebox_override('focus',h);b.add_theme_stylebox_override('pressed',h);v.add_child(b);b.pressed.connect(action)
func main_menu():
 state='menu';menu_open=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;clear_ui();menu_camera.current=true
 menu_camera.position=Vector3(1,3.1,-15);menu_camera.look_at(Vector3(-2,3.5,2));menu_camera.fov=65
 Frontend.main(self)
func class_menu():Frontend.classes(self)
func pause_menu():
 menu_open=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;clear_ui();Frontend.backdrop(self,true);var v=panel(Vector2(570,210),Vector2(450,380));label(v,'MATCH IN PROGRESS',26)
 button(v,'RESUME',resume);button(v,'SETTINGS',func():settings_menu(true));button(v,'CHANGE CLASS ON RESPAWN',pause_classes);button(v,'LEAVE MATCH',leave_match)
func pause_classes():Frontend.classes(self,true)
func queue_class(c: int):
 selected_class=clampi(c,0,2)
 if net_mode=='client':class_request.rpc_id(1,selected_class)
 elif player:player.queued_class=selected_class
@rpc('any_peer','call_remote','reliable')
func class_request(c: int):
 if not authority():return
 var sender=multiplayer.get_remote_sender_id()
 if peer_slots.has(sender):fighters[peer_slots[sender]].queued_class=clampi(c,0,2)
func resume():menu_open=false;clear_ui();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func settings_menu(in_match: bool):
 clear_ui();Frontend.backdrop(self,true);var v=panel(Vector2(500,95),Vector2(600,700));label(v,'SETTINGS',30)
 for entry in [['sensitivity','MOUSE SENSITIVITY',.3,4.0,.1],['fov','FIELD OF VIEW',75,110,1],['volume','MASTER VOLUME',0,1,.05]]:
  var key=entry[0];var l=label(v,entry[1]+'   '+str(settings[key]),17);var slider=HSlider.new();slider.min_value=entry[2];slider.max_value=entry[3];slider.step=entry[4];slider.value=settings[key];v.add_child(slider)
  slider.value_changed.connect(func(value):settings[key]=value;l.text=entry[1]+'   '+str(snappedf(value,.01));save_settings())
 label(v,'GRAPHICS',13)
 var quality=OptionButton.new()
 for preset in ['PERFORMANCE','BALANCED','QUALITY']:quality.add_item(preset)
 quality.selected=settings.graphics;v.add_child(quality);quality.item_selected.connect(func(value):settings.graphics=value;save_settings())
 var sync=CheckButton.new();sync.text='VSync';sync.button_pressed=settings.vsync;v.add_child(sync);sync.toggled.connect(func(value):settings.vsync=value;save_settings())
 var check=CheckButton.new();check.text='Fullscreen';check.button_pressed=settings.fullscreen;v.add_child(check);check.toggled.connect(func(value):settings.fullscreen=value;save_settings())
 label(v,'Q  PRIMARY / PISTOL     G  FRAG\n3  ACTIVATE EARNED STREAK     TAB  SCOREBOARD\nESC  MENU     SPACE  JUMP',15)
 button(v,'BACK',pause_menu if in_match else main_menu)
func leave_match():
 clear_combat_effects();net_mode='offline'
 if multiplayer.has_multiplayer_peer():multiplayer.multiplayer_peer=null
 net_mode='offline';dedicated_server=false;local_id=0;peer_slots.clear()
 for f in fighters:f.queue_free()
 fighters.clear();player=null;main_menu()
func clear_combat_effects():
 for g in grenades:g.node.queue_free()
 grenades.clear()
 for effect in fx:effect.node.queue_free()
 fx.clear()
func start_match(all_bots: bool):
 all_bots=all_bots or dedicated_server
 var old_classes=[]
 for actor in fighters:old_classes.append(actor.queued_class if actor.queued_class>=0 else actor.class_id)
 clear_combat_effects()
 clear_ui();menu_open=false;state='match';scores=[0,0];time_left=420;match_number+=1;feed.clear();radar_time=[0.0,0.0]
 for f in fighters:f.queue_free()
 fighters.clear();player=null
 for i in range(12):
  var f=Fighter.new();f.game=self;f.id=i;f.name='Fighter'+str(i);f.team=0 if i<6 else 1;f.class_id=old_classes[i] if old_classes.size()==12 else i%3;f.local_player=i==local_id and not all_bots;f.bot=not f.local_player;fighters.append(f);add_child(f);f.spawn()
  if f.local_player:player=f;f.load_class(selected_class)
 if player:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 else:menu_camera.current=true
 if net_mode=='host':
  for peer in peer_slots:
   fighters[peer_slots[peer]].bot=false
  sync_start.rpc(match_number)
func safe_spawn(team: int) -> Vector3:
 var best: Vector3=arena.spawns[team][0];var best_score=-999.0
 # After opening deployment, switch ends when the original spawn side is under pressure.
 var candidates=arena.spawns[team] if time_left>414 else arena.spawns[team]+arena.spawns[1-team]
 for p in candidates:
  var closest=80.0;var score=randf()*3+(7.0 if p in arena.spawns[team] else 0.0)
  for f in fighters:
   if f.dead:continue
   var d=p.distance_to(f.global_position)
   if f.team!=team:
    closest=minf(closest,d)
    if d<35:
     var query=PhysicsRayQueryParameters3D.create(p+Vector3.UP*1.6,f.eye(),1)
     if get_world_3d().direct_space_state.intersect_ray(query).is_empty():score-=22
   elif d<3:score-=8
  score+=closest
  if score>best_score:best_score=score;best=p
 return best
func _input(event):
 if event.is_action_pressed('escape') and state=='match':
  if menu_open:resume()
  else:pause_menu()
func _physics_process(dt):
 if state=='match' and authority():
  time_left-=dt
  if bot_test:test_elapsed+=dt
func _process(dt):
 if '--net-test' in OS.get_cmdline_user_args():
  net_test_age+=dt
  if net_test_age>15:push_error('NETWORK_TIMEOUT snapshots='+str(snapshot_count));get_tree().quit(1)
 head_time=maxf(0,head_time-dt);hit_time=maxf(0,hit_time-dt);kill_time=maxf(0,kill_time-dt);damage_flash=maxf(0,damage_flash-dt*1.7)
 if state=='match':
  if authority():
   for i in range(2):radar_time[i]=maxf(0,radar_time[i]-dt)
   if time_left<=0 or scores.max()>=score_limit:end_match()
  if bot_test:
   if test_elapsed>test_goal*480:finish_tests(false,'Match stalled')
  if showcase:
   player.yaw+=sin(Time.get_ticks_msec()*.0002)*dt*.025
  if capture_at>0:
   capture_at-=dt
   if capture_at<=0:
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(capture_path));print('CAPTURE_SAVED');get_tree().quit()
 for i in range(feed.size()-1,-1,-1):
  feed[i].time-=dt
  if feed[i].time<=0:feed.remove_at(i)
 update_fx(dt);update_grenades(dt)
 if net_mode!='offline':network_tick(dt)
 if '--net-test' in OS.get_cmdline_user_args() and player:
  if snapshot_count>10 and snapshot_count<35:Input.action_press('forward')
  else:Input.action_release('forward')
  if snapshot_count>10 and snapshot_count<100:Input.action_press('fire')
  else:Input.action_release('fire')
 if '--net-test' in OS.get_cmdline_user_args() and snapshot_count>=120:
  if player.predicted_shots==0:push_error('NETWORK_TEST_NO_FIRE');get_tree().quit(1);return
  print('NETWORK_OK snapshots=',snapshot_count,' slot=',local_id,' actors=',fighters.size(),' score=',scores,' predicted_shots=',player.predicted_shots,' ammo=',player.ammo,' acknowledged=',player.acknowledged_fire,' pending=',player.pending_predictions.size())
  get_tree().quit()
func confirm_kill(attacker: Fighter, victim: Fighter, zone: String):
 if state!='match':return
 scores[attacker.team]+=1
 feed.push_front({'killer':callsign(attacker),'victim':callsign(victim),'team':attacker.team,'head':zone=='HEAD','time':5.0})
 if feed.size()>5:feed.pop_back()
 if zone=='HEAD':test_headshots+=1
 if attacker.local_player:kill_zone=zone;kill_time=1.6;sound('kill',attacker.eye(),true,-5)
 if net_mode=='host':kill_event.rpc(attacker.id,victim.id,zone,scores)
func callsign(f: Fighter) -> String:return 'YOU' if f.local_player else ['HOLLOW','MICA','ROOK','TRACE','SLATE','VEX','CINDER','DUSK','FLINT','ASH','BRACE','SABLE'][f.id]
func end_match():
 state='results'
 print('MATCH_END ',match_number,' SCORE ',scores,' HEADSHOTS ',test_headshots,' SHOTS ',test_shots)
 if bot_test:
  test_matches+=1
  if test_matches>=test_goal:finish_tests(true,'completed')
  else:call_deferred('start_match',true)
  return
 if net_mode=='host':
  finish_remote.rpc(scores)
  if dedicated_server:
   var generation=match_number
   get_tree().create_timer(8.0).timeout.connect(func():
    if state=='results' and match_number==generation:start_match(true))
 show_results()
func show_results():
 menu_open=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;clear_ui()
 var v=panel(Vector2(450,95),Vector2(700,710));var won=scores[0]>scores[1]
 label(v,'CEASEFIRE / '+('DRAW' if scores[0]==scores[1] else ('AEGIS WINS' if won else 'EMBER WINS')),30,Color('#e1dac5'));label(v,str(scores[0])+' : '+str(scores[1])+'     FOUNDRY DISTRICT',26)
 var ordered=fighters.duplicate();ordered.sort_custom(func(a,b):return a.kills>b.kills)
 for f in ordered:label(v,'%s   /   %s    %d K    %d D' % [callsign(f),'AEGIS' if f.team==0 else 'EMBER',f.kills,f.deaths],16)
 if net_mode!='client':button(v,'NEXT MATCH',func():start_match(false))
 button(v,'MAIN MENU',leave_match)
func finish_tests(success: bool, reason: String):
 var report={'success':success,'reason':reason,'matches':test_matches,'seed':test_seed,'shots':test_shots,'headshots':test_headshots,'simulation_seconds':test_elapsed,'score':scores,'recoveries':test_recoveries,'fighters':[]}
 for f in fighters:report.fighters.append({'id':f.id,'kills':f.kills,'deaths':f.deaths,'position':[f.position.x,f.position.y,f.position.z],'travelled':f.distance_travelled,'recoveries':f.recoveries,'spawn_deaths':f.spawn_deaths})
 var prefix='res://tests/' if OS.has_feature('editor') else 'user://'
 var file=FileAccess.open(prefix+'bot_report_'+str(test_seed)+'.json',FileAccess.WRITE)
 if file:file.store_string(JSON.stringify(report,'  '))
 print('BOT_TEST ',JSON.stringify(report));get_tree().quit(0 if success else 1)
func sound(key: String, pos: Vector3, local: bool=false, volume: float=0):
 if bot_test or DisplayServer.get_name()=='headless':return
 var audio: Node
 if local:audio=AudioStreamPlayer.new()
 else:audio=AudioStreamPlayer3D.new();audio.max_distance=65;audio.unit_size=9
 audio.stream=sound_cache.get(key);audio.bus=AudioMix.bus(self,key,pos,local);audio.volume_db=volume;audio.pitch_scale=randf_range(.985,1.015) if key in ['rifle','smg','marksman','pistol'] else randf_range(.96,1.04);add_child(audio)
 if audio is Node3D:audio.global_position=pos
 audio.finished.connect(audio.queue_free);audio.play()
func add_fx(node: Node3D, life: float, velocity: Vector3=Vector3.ZERO, gravity: bool=false):
 fx.append({'node':node,'life':life,'total':life,'velocity':velocity,'gravity':gravity})
func update_fx(dt):
 for i in range(fx.size()-1,-1,-1):
  var f=fx[i];f.life-=dt
  if f.life<=0:f.node.queue_free();fx.remove_at(i);continue
  var before=f.node.position
  var after=before+f.velocity*dt
  if f.gravity:
   f.velocity.y-=12*dt
   var query=PhysicsRayQueryParameters3D.create(before,after,1)
   var contact=get_world_3d().direct_space_state.intersect_ray(query)
   if not contact.is_empty():after=contact.position+contact.normal*.01;f.velocity=Vector3.ZERO;f.gravity=false
   else:f.node.rotate_x(dt*6)
  f.node.position=after
  if f.node is Sprite3D:
   f.node.modulate.a=minf(1,f.life/f.total*2)
   f.node.scale+=Vector3.ONE*dt*.22
  if f.node is OmniLight3D:f.node.light_energy=f.life/f.total*1.6
func smoke_sprite(pos: Vector3, scale_v: float, life: float, velocity: Vector3, tint: Color=Color('#87877b')):
 var sprite=Sprite3D.new();sprite.texture=load('res://assets/smoke.png');sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sprite.pixel_size=.01;sprite.modulate=tint;sprite.no_depth_test=false
 add_child(sprite);sprite.position=pos;sprite.scale=Vector3.ONE*scale_v;add_fx(sprite,life,velocity)
func muzzle(pos: Vector3, _dir: Vector3):
 if bot_test or dedicated_server or DisplayServer.get_name()=='headless':return
 var flash=Sprite3D.new();flash.texture=load('res://assets/muzzle.png');flash.billboard=BaseMaterial3D.BILLBOARD_ENABLED;flash.pixel_size=.002;flash.shaded=false
 add_child(flash);flash.position=pos;flash.rotation.z=randf()*TAU;add_fx(flash,.035)
 if fx.size()<160:
  var light=OmniLight3D.new();add_child(light);light.position=pos;light.light_color=Color('#ffa659');light.omni_range=3;light.light_energy=1.6;add_fx(light,.065)
  smoke_sprite(pos,.12,.24,Vector3.UP*.3,Color('#b0ada0'))
func shell(pos: Vector3):
 if bot_test or dedicated_server or DisplayServer.get_name()=='headless':return
 var m=Art.cylinder(self,pos,.005,.028,Art.mat('brass',Color('#b49357'),.8))
 var right=Vector3.RIGHT.rotated(Vector3.UP,player.yaw if player else 0)
 add_fx(m,3,right*randf_range(1.7,2.6)+Vector3(0,1.4,randf_range(-.5,.5)),true)
func impact(pos: Vector3, normal: Vector3, material: String):
 if bot_test or dedicated_server or DisplayServer.get_name()=='headless':return
 var metal=material=='metal'
 var flesh=material=='flesh'
 var color=Color('#806552') if flesh else (Color('#ffd59a') if metal else Color('#85887b'))
 sound('impact_body' if flesh else ('impact_metal' if metal else 'impact_concrete'),pos,false,-16 if metal else -20)
 for i in range(4 if metal else 3):
  var particle_material=Art.mat('impact'+material,color)
  if metal:particle_material.emission_enabled=true;particle_material.emission=color;particle_material.emission_energy_multiplier=1.8
  var m=Art.box(self,pos+normal*.015,Vector3(.008,.008,.055) if metal else Vector3(.018,.013,.019),particle_material)
  add_fx(m,randf_range(.10,.28),normal*randf_range(.7,2)+Vector3(randf_range(-1,1),randf(),randf_range(-1,1)),true)
 if not flesh:
  for i in range(2):smoke_sprite(pos+normal*.04,.20,.48,normal*.4+Vector3.UP*.3,Color('#8b8c7e'))
  var mark=Art.cylinder(self,pos+normal*.003,.025,.001,Art.mat('bulletmark',Color('#303830')))
  mark.basis=Basis(Quaternion(Vector3.UP,normal));add_fx(mark,20)
func tracer(from: Vector3, to: Vector3):
 if bot_test or dedicated_server or DisplayServer.get_name()=='headless' or from.distance_to(to)<2:return
 var length=minf(2.0,from.distance_to(to)*.16)
 var direction=(to-from).normalized();var middle=from.lerp(to,.70)
 var m=Art.cylinder(self,middle,.004,length,Art.mat('tracer',Color('#e7cb96')))
 m.basis=Basis(Quaternion(Vector3.UP,direction));add_fx(m,.038)
func grenade(owner: Fighter, pos: Vector3, vel: Vector3):
 if net_mode=='host':grenade_event.rpc(owner.id,pos,vel)
 var body=RigidBody3D.new();add_child(body);body.position=pos;body.linear_velocity=vel;body.mass=.4;body.collision_layer=4;body.collision_mask=1
 var shape=CollisionShape3D.new();var sphere_shape=SphereShape3D.new();sphere_shape.radius=.12;shape.shape=sphere_shape;body.add_child(shape)
 Art.sphere(body,Vector3.ZERO,Vector3.ONE*.22,Art.mat('grenade',Color('#52614b')))
 grenades.append({'node':body,'owner':owner,'time':2.1})
func update_grenades(dt):
 for i in range(grenades.size()-1,-1,-1):
  var g=grenades[i];g.time-=dt
  if g.time<=0:
   if authority():explode(g.node.global_position,g.owner,7,130)
   g.node.queue_free();grenades.remove_at(i)
@rpc('authority','call_remote','reliable')
func grenade_event(owner_id: int, pos: Vector3, vel: Vector3):
 if fighters.size()==12 and state=='match':grenade(fighters[owner_id],pos,vel)
@rpc('authority','call_remote','unreliable')
func explosion_event(pos: Vector3, owner_id: int, radius: float):
 if fighters.size()==12 and state=='match':explode(pos,fighters[owner_id],radius,0)
func explode(pos: Vector3, owner: Fighter, radius: float, damage: float):
 if net_mode=='host':explosion_event.rpc(pos,owner.id,radius)
 sound('explosion',pos,false,1)
 if not bot_test and not dedicated_server and DisplayServer.get_name()!='headless':
  var light=OmniLight3D.new();add_child(light);light.position=pos;light.omni_range=12;light.light_color=Color('#ffb45b');light.light_energy=2;add_fx(light,.3)
  for i in range(25):
   smoke_sprite(pos,randf_range(.8,1.8),randf_range(1.0,2.5),Vector3(randf_range(-2,2),randf_range(1,3),randf_range(-2,2)),Color('#76746a'))
 if not authority():return
 for f in fighters:
  if f.dead or f.team==owner.team:continue
  var d=f.global_position.distance_to(pos)
  if d<radius:
   var q=PhysicsRayQueryParameters3D.create(pos+Vector3.UP*.3,f.eye(),1)
   if get_world_3d().direct_space_state.intersect_ray(q).is_empty():f.hurt(damage*(1-d/radius)*(.75 if f.class_id==2 else 1),owner,'BLAST')
func use_streak(owner: Fighter, tier: int):
 if tier==3:radar_time[owner.team]=20
 elif tier==5:
  var enemies=fighters.filter(func(f):return f.team!=owner.team and not f.dead)
  if not enemies.is_empty():
   var target=enemies.pick_random().global_position
   for i in range(4):
    var point=target+Vector3(randf_range(-3,3),.3,randf_range(-3,3));var generation=match_number;var shooter_id=owner.id
    get_tree().create_timer(.9+i*.28).timeout.connect(func():
     if generation==match_number and state=='match' and fighters.size()==12:explode(point,fighters[shooter_id],9,150))
 else:
  for i in range(10):
   var generation=match_number;var shooter_id=owner.id
   get_tree().create_timer(.3+i*.65).timeout.connect(func():
    if generation==match_number and fighters.size()==12:support_shot(fighters[shooter_id]))
 if owner.local_player:feed.push_front({'killer':'SUPPORT','victim':{3:'RECON ONLINE',5:'MORTAR INBOUND',7:'OVERWATCH ONLINE'}[tier],'team':owner.team,'head':false,'time':4.0})
func support_shot(owner: Fighter):
 if state!='match':return
 var enemies=fighters.filter(func(f):return f.team!=owner.team and not f.dead)
 if enemies.is_empty():return
 var target=enemies.pick_random();var origin=target.eye()+Vector3(0,20,0);var q=PhysicsRayQueryParameters3D.create(origin,target.eye(),1)
 if get_world_3d().direct_space_state.intersect_ray(q).is_empty():target.hurt(45,owner,'SUPPORT');impact(target.eye(),Vector3.UP,'metal');sound('marksman',origin)
# ENet: server simulates bots, damage, score and respawn. Clients send intent only.
func start_host(dedicated: bool):
 var peer=ENetMultiplayerPeer.new();var err=peer.create_server(27841,12 if dedicated else 11)
 if err!=OK:show_error('Cannot bind UDP 27841: '+error_string(err));return
 multiplayer.multiplayer_peer=peer;net_mode='host';local_id=0;dedicated_server=dedicated
 start_match(dedicated);print('SERVER_READY UDP 27841')
func start_client(address: String):
 var peer=ENetMultiplayerPeer.new();var err=peer.create_client('127.0.0.1' if address.is_empty() else address,27841)
 if err!=OK:show_error(error_string(err));return
 multiplayer.multiplayer_peer=peer;net_mode='client';snapshot_count=0;net_test_age=0
 clear_ui();var v=panel(Vector2(500,300),Vector2(580,200));label(v,'CONNECTING TO SERVER…',24);button(v,'CANCEL',leave_match)
func show_error(words: String):
 var v=panel(Vector2(550,650),Vector2(650,100));label(v,words,17,Color('#dda07a'))
var peer_slots: Dictionary={}
func peer_joined(_peer: int):pass
func peer_left(peer: int):
 if peer_slots.has(peer):
  var slot=peer_slots[peer]
  if slot<fighters.size():fighters[slot].bot=true;fighters[slot].collision_mask=1
  peer_slots.erase(peer)
@rpc('any_peer','call_remote','reliable')
func request_slot(c: int):
 if not authority():return
 var sender=multiplayer.get_remote_sender_id();var used=peer_slots.values()
 if not dedicated_server:used.append(0)
 for slot in range(12):
  if slot not in used:
   peer_slots[sender]=slot;var f=fighters[slot];f.bot=false;f.collision_mask=1|2;f.kills=0;f.deaths=0;f.streak=0;f.rewards.clear();f.load_class(clampi(c,0,2));f.spawn();assign_slot.rpc_id(sender,slot,match_number);return
 connection_denied.rpc_id(sender)
@rpc('authority','call_remote','reliable')
func connection_denied():leave_match();show_error('Server is full')
@rpc('authority','call_remote','reliable')
func assign_slot(slot: int, number: int):
 local_id=slot;match_number=number-1;start_match(false)
@rpc('authority','call_remote','reliable')
func sync_start(number: int):
 if net_mode=='client':match_number=number-1;start_match(false)
func network_tick(dt: float):
 net_timer+=dt
 if net_timer<.033:return
 net_timer=0
 if net_mode=='client' and player and state=='match':
  var input={'x':player.move_wish.x,'z':player.move_wish.y,'yaw':player.yaw,'pitch':player.pitch,'ads':player.ads,'sprint':player.sprinting,'crouch':player.crouched,'fire':Input.is_action_pressed('fire') and not menu_open,'jump':Input.is_action_pressed('jump') and not menu_open}
  submit_input.rpc_id(1,input)
 elif net_mode=='host':
  var data=[]
  for f in fighters:data.append([f.position,f.yaw,f.pitch,f.health,f.dead,f.kills,f.deaths,f.streak,f.ammo,f.reserves,f.weapon_id,f.respawn_time,f.rewards,f.class_id,f.reload_left,f.crouched,f.acknowledged_fire])
  snapshot.rpc(var_to_bytes(data).compress(FileAccess.COMPRESSION_DEFLATE),scores,time_left,radar_time)
@rpc('any_peer','call_remote','unreliable_ordered')
func submit_input(input: Dictionary):
 if not authority():return
 var sender=multiplayer.get_remote_sender_id()
 if peer_slots.has(sender):fighters[peer_slots[sender]].network_input=input
func send_action(action: String):action_request.rpc_id(1,action,0,Vector2.ZERO,-1,match_number)
func send_shot(actor: Fighter, aim: Vector2):
 actor.fire_sequence+=1;actor.pending_predictions.append({'sequence':actor.fire_sequence,'weapon':actor.weapon_id})
 action_request.rpc_id(1,'fire',actor.fire_sequence,aim,actor.weapon_id,match_number)
@rpc('any_peer','call_remote','reliable')
func action_request(action: String, sequence: int, aim: Vector2, weapon: int, generation: int):
 if not authority():return
 var sender=multiplayer.get_remote_sender_id()
 if not peer_slots.has(sender) or generation!=match_number or state!='match':return
 var f=fighters[peer_slots[sender]]
 match action:
  'fire':
   if sequence<=f.acknowledged_fire or not aim.is_finite():return
   if f.dead or f.reload_left>0 or weapon!=f.weapon_id:
    f.acknowledged_fire=sequence;return
   if f.pending_remote_shots.size()<4:f.pending_remote_shots.append({'sequence':sequence,'aim':Vector2(aim.x,clampf(aim.y,-1.45,1.45)),'weapon':weapon})
  'reload':
   if f.pending_remote_shots.is_empty():f.start_reload()
   else:f.reload_requested=true
  'switch':f.switch_weapon()
  'grenade':f.throw_grenade()
  'streak':f.activate_streak()
@rpc('authority','call_remote','unreliable_ordered')
func snapshot(packed: PackedByteArray, score: Array, clock: float, radar: Array):
 var unpacked=packed.decompress_dynamic(65536,FileAccess.COMPRESSION_DEFLATE)
 if unpacked.is_empty():return
 var data=bytes_to_var(unpacked)
 if not data is Array or data.size()!=12 or fighters.size()!=12:return
 snapshot_count+=1;scores=score;time_left=clock;radar_time=radar
 for i in range(12):
  var f=fighters[i];var s=data[i]
  var displacement=f.position.distance_to(s[0])
  if not f.local_player and not s[4]:
   f.walk_phase+=displacement*1.8
   f.model.get_node('LegL').rotation.x=sin(f.walk_phase)*.45
   f.model.get_node('LegR').rotation.x=-sin(f.walk_phase)*.45
  if f.local_player:f.position=f.position.lerp(s[0],.35) if displacement<3 else s[0]
  else:
   f.network_position=s[0];f.network_yaw=s[1]
   if not f.network_pose_ready or displacement>3 or f.dead!=s[4]:f.position=s[0];f.rotation.y=s[1]
   f.network_pose_ready=true;f.yaw=s[1];f.pitch=s[2]
  f.health=s[3];f.dead=s[4];f.kills=s[5];f.deaths=s[6];f.streak=s[7];f.ammo=s[8];f.reserves=s[9];f.respawn_time=s[11];f.rewards.assign(s[12]);f.class_id=s[13];f.reload_left=s[14];f.crouched=s[15];f.col.shape.height=1.2 if f.crouched else 1.8;f.col.position.y=.6 if f.crouched else .9;f.model.visible=not f.local_player or f.dead;f.model.rotation.x=-1.48 if f.dead else 0;f.model.position.y=.12 if f.dead else (-.42 if f.crouched else 0);f.collision_layer=0 if f.dead else 2
  if f.local_player:
   f.acknowledged_fire=s[16]
   f.pending_predictions=f.pending_predictions.filter(func(shot):return shot.sequence>f.acknowledged_fire)
   if f.dead:f.pending_predictions.clear()
   for shot in f.pending_predictions:f.ammo[shot.weapon]=maxi(0,f.ammo[shot.weapon]-1)
  if f.weapon_id!=s[10]:
   f.weapon_id=s[10];f.update_world_weapon()
   if f.local_player:f.build_gun()
  if f.local_player:f.gun.visible=not f.dead
@rpc('authority','call_remote','unreliable')
func damage_event(target: int, shooter: int, pos: Vector3, zone: String):
 if fighters.size()!=12 or state!='match':return
 if target==local_id:damage_flash=.5
 if shooter==local_id:
  hit_time=.16;sound('hit',player.eye(),true,-7)
  if zone=='HEAD':head_time=.3
 impact(pos,Vector3.UP,'flesh')
func broadcast_impact(who: int, position: Vector3, normal: Vector3, surface: String):
 if net_mode=='host':impact_event.rpc(who,position,normal,surface)
@rpc('authority','call_remote','unreliable')
func impact_event(who: int, position: Vector3, normal: Vector3, surface: String):
 if fighters.size()!=12 or state!='match' or who==local_id:return
 impact(position,normal,surface)
func broadcast_shot(who: int, origin: Vector3, dir: Vector3):
 test_shots+=1
 if net_mode=='host':shot_event.rpc(who,origin,dir)
@rpc('authority','call_remote','unreliable')
func shot_event(who: int, origin: Vector3, dir: Vector3):
 if fighters.size()!=12 or state!='match':return
 var f=fighters[who]
 if f.local_player:return # Local predicted recoil/audio already played.
 sound(Arsenal.WEAPONS[f.weapon_id].sound,origin,f.local_player,-3)
 if f.local_player:f.view.fire(f.weapon_id);f.kick+=.038;f.pitch+=deg_to_rad(Arsenal.WEAPONS[f.weapon_id].recoil);muzzle(f.gun.to_global(f.gun.get_meta('muzzle')),dir)
 else:muzzle(origin+dir*.55,dir)
@rpc('authority','call_remote','reliable')
func kill_event(killer: int, victim: int, zone: String, score: Array):
 if fighters.size()!=12 or state!='match':return
 scores=score;feed.push_front({'killer':callsign(fighters[killer]),'victim':callsign(fighters[victim]),'team':fighters[killer].team,'head':zone=='HEAD','time':5.0})
 if killer==local_id:kill_zone=zone;kill_time=1.6;hit_time=.2;sound('kill',player.eye(),true,-5)
@rpc('authority','call_remote','reliable')
func finish_remote(score: Array):scores=score;state='results';show_results()
