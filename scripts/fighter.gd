class_name Fighter
extends CharacterBody3D
var game: Node3D
var id: int
var team: int
var local_player=false
var bot=true
var class_id=0
var queued_class=-1
var weapon_id=0
var primary=0
var ammo=[30,36,14,12]
var reserves=[120,144,56,48]
var health=100.0
var kills=0
var deaths=0
var streak=0
var rewards: Array[int]=[]
var grenades=2
var dead=false
var respawn_time=0.0
var cooldown=0.0
var reload_left=0.0
var damage_age=0.0
var yaw=0.0
var pitch=0.0
var ads=false
var sprinting=false
var crouched=false
var camera: Camera3D
var rig: Node3D
var gun: Node3D
var view=WeaponView.new()
var recoil_sequence=0
var recoil_return=Vector2.ZERO
var shot_age=1.0
var sprint_blend=0.0
var predicted_shots=0
var pending_fire=false
var fire_sequence=0
var acknowledged_fire=0
var pending_predictions: Array[Dictionary]=[]
var pending_remote_shots: Array[Dictionary]=[]
var reload_requested=false
var model: Node3D
var world_gun: Node3D
var body_motion: CharacterMotion
var death_motion: Tween
var spawn_deaths=0
var kick=0.0
var sway=Vector2.ZERO
var walk_phase=0.0
var landing=0.0
var step_visual=0.0
var trigger_was=false
var bot_think=0.0
var bot_age=0.0
var bot_aim_height=1.17
var bot_error=Vector2.ZERO
var bot_burst=0
var bot_pause=0.0
var distance_travelled=0.0
var recoveries=0
var last_known=Vector3.ZERO
var memory_time=0.0
var life_age=0.0
var bot_target: Fighter
var path=PackedVector2Array()
var path_index=0
var bot_reaction=0.0
var move_wish=Vector2.ZERO
var last_position=Vector3.ZERO
var stuck_time=0.0
var last_shot=0.0
var cover_point=Vector3.ZERO
var cover_time=0.0
var col: CollisionShape3D
var step_timer=0.0
var network_input: Dictionary={}
var remote_jump_held=false
var network_position=Vector3.ZERO
var network_yaw=0.0
var network_pose_ready=false
var standing_clearance=SphereShape3D.new()
func _ready():
 collision_layer=2;collision_mask=1 if bot else 1|2
 floor_snap_length=.32;floor_stop_on_slope=true;standing_clearance.radius=.29
 col=CollisionShape3D.new();var cap=CapsuleShape3D.new();cap.radius=.30;cap.height=1.8;col.shape=cap;col.position.y=.9;add_child(col)
 model=Art.soldier(self,team)
 body_motion=CharacterMotion.new()
 if not body_motion.bind(self):body_motion=null
 if local_player:
  model.visible=false
  camera=Camera3D.new();add_child(camera);camera.position.y=1.62;camera.current=true;camera.fov=game.settings.fov;camera.near=.045
  rig=Node3D.new();camera.add_child(rig);build_gun()
 load_class(class_id)
func build_gun():
 if gun:
  gun.visible=false;gun.get_parent().remove_child(gun);gun.queue_free()
 gun=Art.weapon(rig,weapon_id)
 view.bind(gun)
func load_class(c: int):
 class_id=c;primary=Arsenal.CLASSES[c].weapon;weapon_id=primary
 ammo=[30,36,14,12];reserves=[120,144,56,48];grenades=2;reload_left=0
 if local_player and rig:build_gun()
 update_world_weapon()
func update_world_weapon():
 var old=model.find_child('WorldWeapon',true,false)
 if old:
  old.visible=false;old.get_parent().remove_child(old);old.queue_free()
 world_gun=Art.weapon(model,weapon_id,false);world_gun.name='WorldWeapon';world_gun.position=Vector3(.13,1.17,-.37);world_gun.scale=Vector3.ONE*.8
 if body_motion:body_motion.attach_weapon(world_gun)
func eye() -> Vector3:return global_position+Vector3(0,1.03 if crouched else 1.62,0)
func aim_dir() -> Vector3:return Vector3(-sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))
func _input(event):
 if not local_player or dead or game.state!='match' or game.menu_open:return
 if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  yaw-=event.screen_relative.x*game.settings.sensitivity*.001
  var look_y=-event.screen_relative.y*game.settings.sensitivity*.001
  if look_y<0:recoil_return.x=maxf(0,recoil_return.x+look_y)
  pitch=clampf(pitch+look_y,-1.45,1.45)
  sway=Vector2(clampf(event.relative.x*.0003,-.02,.02),clampf(event.relative.y*.0003,-.02,.02))
 if event.is_action_pressed('reload'):
  if game.authority():start_reload()
  else:start_reload();game.send_action('reload')
 if event.is_action_pressed('switch'):
  if game.authority():switch_weapon()
  else:game.send_action('switch')
 if event.is_action_pressed('grenade'):throw_grenade()
 if event.is_action_pressed('streak'):activate_streak()
func switch_weapon():
 weapon_id=3 if weapon_id!=3 else primary;reload_left=0;cooldown=.23
 if local_player:build_gun();kick=.06
 update_world_weapon()
func _physics_process(dt):
 if game.state!='match':return
 if not game.authority() and not local_player:return
 cooldown=maxf(-dt,cooldown-dt);shot_age+=dt;last_shot=maxf(0,last_shot-dt);damage_age+=dt;life_age+=dt
 if dead:
  if local_player:
   camera.position.y=lerpf(camera.position.y,.85,dt*3);camera.rotation.x=lerpf(camera.rotation.x,-.18,dt*2)
  respawn_time-=dt
  if respawn_time<=0 and game.authority():spawn()
  return
 if local_player:recover_recoil(dt)
 if reload_left>0:
  reload_left-=dt
  if reload_left<=0 and game.authority():
   var need=Arsenal.WEAPONS[weapon_id].mag-ammo[weapon_id];var take=mini(need,reserves[weapon_id]);ammo[weapon_id]+=take;reserves[weapon_id]-=take
 if damage_age>4:health=minf(100,health+dt*24)
 var was_crouched=crouched
 if bot and game.authority():think_bot(dt)
 elif local_player:
  if not game.menu_open:
   move_wish=Input.get_vector('left','right','forward','back');ads=Input.is_action_pressed('ads');crouched=Input.is_action_pressed('crouch');sprinting=Input.is_action_pressed('sprint') and move_wish.y<-.2 and not ads and not crouched and not Input.is_action_pressed('fire') and reload_left<=0
   if Input.is_action_just_pressed('jump') and is_on_floor():velocity.y=5.7
   var pressed=Input.is_action_pressed('fire')
   if pressed and (Arsenal.WEAPONS[weapon_id].auto or not trigger_was):shoot()
   trigger_was=pressed
  else:move_wish=Vector2.ZERO;ads=false;sprinting=false
 elif not bot:
  apply_remote_input()
  if not pending_remote_shots.is_empty() and cooldown<=0:
   var request=pending_remote_shots.pop_front();acknowledged_fire=maxi(acknowledged_fire,request.sequence)
   if request.weapon==weapon_id:
    var latest_aim=Vector2(yaw,pitch);yaw=request.aim.x;pitch=request.aim.y;shoot();yaw=latest_aim.x;pitch=latest_aim.y
  if reload_requested and pending_remote_shots.is_empty():reload_requested=false;start_reload()
 if was_crouched and not crouched and not can_stand():crouched=true
 var direction=Vector3(move_wish.x,0,move_wish.y).rotated(Vector3.UP,yaw)
 if bot and direction.length_squared()>.1:
  for ally in game.fighters:
   if ally==self or ally.dead:continue
   var separation=global_position-ally.global_position;separation.y=0
   var distance=separation.length()
   if distance>.05 and distance<.8:direction+=separation.normalized()*(.8-distance)*1.2
  direction=direction.normalized()
 var speed=7.8 if sprinting else (2.5 if crouched else (3.2 if ads else 5.1))
 if sprinting and class_id==1:speed*=1.12
 velocity.x=move_toward(velocity.x,direction.x*speed,dt*45);velocity.z=move_toward(velocity.z,direction.z*speed,dt*45)
 col.shape.height=1.2 if crouched else 1.8;col.position.y=.6 if crouched else .9
 var was_floor=is_on_floor()
 if not was_floor:velocity.y-=18*dt
 var previous=global_position
 var horizontal=Vector3(velocity.x,0,velocity.z)*dt
 if was_floor and horizontal.length_squared()>.000001 and test_move(global_transform,horizontal):
  var raised=global_transform;raised.origin.y+=.24
  if not test_move(global_transform,Vector3.UP*.24) and not test_move(raised,horizontal):
   global_position.y+=.24;step_visual+=.24;step_visual=minf(step_visual,.30)
 move_and_slide()
 distance_travelled+=global_position.distance_to(previous)
 if not was_floor and is_on_floor():landing=.055
 rotation.y=yaw
 var moving=Vector2(velocity.x,velocity.z).length()
 walk_phase+=dt*moving*1.8
 if model and not game.bot_test and not body_motion:
  if not dead:model.rotation.z=lerpf(model.rotation.z,0,dt*9)
  model.get_node('LegL').rotation.x=sin(walk_phase)*minf(.55,moving*.09)
  model.get_node('LegR').rotation.x=-sin(walk_phase)*minf(.55,moving*.09)
  var knee=model.find_child('KneeL',true,false)
  if knee:knee.rotation.x=-maxf(0,-sin(walk_phase))*.7*minf(1,moving/5)
  knee=model.find_child('KneeR',true,false)
  if knee:knee.rotation.x=-maxf(0,sin(walk_phase))*.7*minf(1,moving/5)
  if world_gun:world_gun.rotation.x=pitch*.65+last_shot*.04
  model.position.y=-.42 if crouched else 0.0
 if local_player:
  step_timer-=dt
  if moving>2 and was_floor and step_timer<=0:
   var ground=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.2,global_position-Vector3.UP*.3,1))
   var sound_key='step'
   if not ground.is_empty():
    var surface=ground.collider.get_meta('surface','asphalt')
    sound_key='step_metal' if surface=='metal' else ('step_concrete' if surface in ['concrete','brick','plaster'] else 'step')
   game.sound(sound_key,eye(),true,-17);step_timer=.30 if sprinting else .42
func can_stand() -> bool:
 var query=PhysicsShapeQueryParameters3D.new();query.shape=standing_clearance;query.transform=Transform3D(Basis.IDENTITY,global_position+Vector3.UP*1.49);query.collision_mask=1;query.exclude=[get_rid()]
 return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func _process(dt: float):
 if not game.authority() and not local_player and network_pose_ready:
  position=position.lerp(network_position,1-exp(-dt*20));rotation.y=lerp_angle(rotation.y,network_yaw,1-exp(-dt*20))
 if body_motion and game.state=='match':
  body_motion.update(dt)
  if not dead:model.rotation.z=lerpf(model.rotation.z,0,1-exp(-dt*9))
 if not game.authority() and not local_player:last_shot=maxf(0,last_shot-dt)
 if not local_player or not camera or game.state!='match' or dead:return
 # Presentation follows the display rate; authoritative motion and weapon timers stay at 60 Hz.
 var blend=1-exp(-dt*14)
 camera.rotation=Vector3(pitch,yaw-rotation.y,0)
 step_visual=move_toward(step_visual,0,dt*1.6)
 camera.position.y=lerpf(camera.position.y,(1.03 if crouched else 1.62)-step_visual,blend)
 var aiming=ads and not sprinting and reload_left<=0
 camera.fov=lerpf(camera.fov,game.settings.fov*((.52 if weapon_id==2 else .72) if aiming else 1.0),1-exp(-dt*20))
 kick=move_toward(kick,0,dt*.7);landing=move_toward(landing,0,dt*.25);sway=sway.lerp(Vector2.ZERO,1-exp(-dt*10))
 sprint_blend=lerpf(sprint_blend,1.0 if sprinting else 0.0,1-exp(-dt*14))
 view.update(self,dt)
 gun.visible=not (weapon_id==2 and aiming and view.aim_blend>.98)
func recover_recoil(dt: float):
 if shot_age<.14:return
 var correction=recoil_return*(1-exp(-dt*8))
 pitch-=correction.x;yaw-=correction.y;recoil_return-=correction
 if shot_age>.35:recoil_sequence=0
func start_reload():
 if dead or reload_left>0 or ammo[weapon_id]>=Arsenal.WEAPONS[weapon_id].mag or reserves[weapon_id]<=0:return
 reload_left=Arsenal.WEAPONS[weapon_id].reload*(.78 if class_id==0 else 1.0)
 recoil_sequence=0
func shoot():
 if dead or cooldown>0 or reload_left>0 or sprinting:return
 if ammo[weapon_id]<=0:
  if reserves[weapon_id]>0:start_reload()
  elif local_player:game.sound('dryfire',eye(),true,-12);cooldown=.23
  return
 var w=Arsenal.WEAPONS[weapon_id];ammo[weapon_id]-=1;cooldown=maxf(cooldown,-1.0/60.0)+w.interval;last_shot=.4
 if not game.authority():
  predicted_shots+=1;game.send_shot(self,Vector2(yaw,pitch))
  var direction=aim_dir()
  var visual_ray=PhysicsRayQueryParameters3D.create(eye(),eye()+direction*140,1|2,[get_rid()])
  var predicted_hit=get_world_3d().direct_space_state.intersect_ray(visual_ray)
  if not predicted_hit.is_empty() and not predicted_hit.collider is Fighter:game.impact(predicted_hit.position,predicted_hit.normal,predicted_hit.collider.get_meta('surface','concrete'))
  local_fire_feedback(w,direction);return
 var dir=aim_dir();var spread=w.spread*(.18 if ads else 1.0)*(1.7 if not is_on_floor() else 1.0)
 dir=(dir+Vector3(randf_range(-spread,spread),randf_range(-spread,spread),randf_range(-spread,spread))).normalized()
 var origin=eye();var ray=PhysicsRayQueryParameters3D.create(origin,origin+dir*140,1|2,[get_rid()]);var hit=get_world_3d().direct_space_state.intersect_ray(ray)
 if local_player:local_fire_feedback(w,dir)
 else:game.sound(w.sound,origin,false,-3);game.muzzle(eye()+dir*.55,dir,weapon_id)
 if not hit.is_empty():
  var target=hit.collider
  if target is Fighter:
   if target.team!=team:
    var h=hit.position.y-target.global_position.y
    var zone='HEAD' if h>(1.03 if target.crouched else 1.48) else ('LEGS' if h<.72 else 'TORSO')
    var damage=w.damage*(2.4 if zone=='HEAD' else (.72 if zone=='LEGS' else 1.0))
    if weapon_id==1:damage*=clampf(1.4-origin.distance_to(hit.position)/50,.6,1)
    target.hurt(damage,self,zone);game.impact(hit.position,hit.normal,'flesh')
    if local_player:
     game.hit_time=.16
     if zone=='HEAD':game.head_time=.3
     game.sound('hit',eye(),true,-7)
  else:
   var material=target.get_meta('surface','concrete')
   game.impact(hit.position,hit.normal,material);game.broadcast_impact(id,hit.position,hit.normal,material)
 if not local_player and randf()<.22:game.tracer(origin+dir*.7,hit.position if not hit.is_empty() else origin+dir*45)
 game.broadcast_shot(id,origin,dir)
func local_fire_feedback(w: Dictionary, direction: Vector3):
 game.sound(w.sound,eye(),true,-3)
 view.fire(weapon_id);recoil_sequence+=1
 kick=minf(.095,kick+.038)
 var rise=deg_to_rad(w.recoil)*(.7 if ads else 1)
 var lateral=deg_to_rad(sin(recoil_sequence*1.75)*.17)
 var previous_pitch=pitch
 pitch=clampf(pitch+rise,-1.45,1.45);yaw+=lateral
 recoil_return+=Vector2((pitch-previous_pitch)*.65,lateral);shot_age=0
 game.muzzle(gun.to_global(gun.get_meta('muzzle')),direction,weapon_id)
 game.shell(gun.to_global(gun.get_meta('ejector',Vector3(.049,.016,-.12))),gun.global_basis.x)
func hurt(amount: float, attacker: Fighter, zone: String):
 if dead or not game.authority() or game.state!='match':return
 if local_player and game.showcase:return
 health-=amount;damage_age=0
 if local_player:game.damage_flash=.5
 model.rotation.z=randf_range(-.06,.06)
 if game.net_mode=='host':game.damage_event.rpc(id,attacker.id,eye(),zone)
 if health<=0:
  dead=true;health=0;deaths+=1;streak=0;rewards.clear();respawn_time=2.3;model.visible=true;collision_layer=0
  if life_age<2:spawn_deaths+=1
  if not game.bot_test and not body_motion:
   death_motion=create_tween();death_motion.set_parallel(true)
   death_motion.tween_property(model,'rotation',Vector3(-1.48,0,randf_range(-.14,.14)),.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
   death_motion.tween_property(model,'position:y',.12,.32)
  if local_player:gun.visible=false
  attacker.kills+=1;attacker.streak+=1
  if attacker.streak in [3,5,7]:attacker.rewards.append(attacker.streak)
  game.confirm_kill(attacker,self,zone)
func spawn():
 if death_motion:death_motion.kill()
 dead=false;pending_fire=false;pending_remote_shots.clear();pending_predictions.clear();reload_requested=false;health=100;collision_layer=2;damage_age=0;velocity=Vector3.ZERO;model.rotation=Vector3.ZERO;model.position=Vector3.ZERO;model.visible=not local_player
 global_position=game.safe_spawn(team);yaw=PI if global_position.z<0 else 0;pitch=0;life_age=0;stuck_time=0;cover_time=0;bot_pause=0;bot_burst=0;load_class(queued_class if queued_class>=0 else class_id);queued_class=-1;path.clear();bot_target=null;bot_think=0
 if body_motion:body_motion.reset()
 if local_player:gun.visible=true;recoil_return=Vector2.ZERO;recoil_sequence=0;shot_age=1;sprint_blend=0;view.aim_blend=0
func throw_grenade():
 if not game.authority():game.send_action('grenade');return
 if dead or grenades<=0:return
 grenades-=1;game.grenade(self,eye()+aim_dir()*.65,aim_dir()*14+Vector3.UP*3)
func activate_streak():
 if not game.authority():game.send_action('streak');return
 if dead or rewards.is_empty():return
 var reward=rewards.pop_front();game.use_streak(self,reward)
func set_route(destination: Vector3):
 path=game.arena.route(global_position,destination);path_index=0
func follow_route(dt: float, face_path: bool=true):
 move_wish=Vector2.ZERO
 while path_index<path.size():
  var point=Vector3(path[path_index].x,global_position.y,path[path_index].y)
  var direction=point-global_position
  if direction.length()<.48:path_index+=1;continue
  if face_path:yaw=lerp_angle(yaw,atan2(-direction.x,-direction.z),dt*12);pitch=0
  var local_direction=direction.normalized().rotated(Vector3.UP,-yaw)
  move_wish=Vector2(local_direction.x,local_direction.z)
  return
func think_bot(dt: float):
 bot_age+=dt;bot_think-=dt;bot_reaction-=dt;cover_time=maxf(0,cover_time-dt);memory_time=maxf(0,memory_time-dt);bot_pause=maxf(0,bot_pause-dt)
 if ammo[weapon_id]==0 and reserves[weapon_id]==0 and weapon_id!=3:switch_weapon()
 if bot_think<=0:
  bot_think=randf_range(.18,.28)
  var nearest: Fighter=null;var distance=999.0
  for other in game.fighters:
   if other.team==team or other.dead:continue
   var d=global_position.distance_to(other.global_position)
   if d<distance and d<40:
    var query=PhysicsRayQueryParameters3D.create(eye(),other.eye(),1|2,[get_rid()])
    var hit=get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty() and hit.collider==other:nearest=other;distance=d
  if nearest!=bot_target:
   bot_reaction=randf_range(.28,.48)
   bot_aim_height=1.56 if randf()<.13 else randf_range(1.04,1.28)
   bot_burst=randi_range(3,6)
  bot_target=nearest
  bot_error=Vector2(randf_range(-.018,.018),randf_range(-.013,.013))
  if bot_target:
   last_known=bot_target.position;memory_time=5
  elif cover_time<=0 and (path.is_empty() or path_index>=path.size()):
   if memory_time>0:set_route(last_known)
   else:
    var lane=[-20.0,-10.0,0.0,10.0,20.0][(id+randi_range(0,2))%5]
    var destination=Vector3(lane,0,randf_range(-20,20))
    if abs(global_position.z)<12 and randf()<.4:destination.z=20 if team==0 else -20
    if randf()<.12:destination=Vector3(26,2.25,-9)
    set_route(destination)
 if is_instance_valid(bot_target) and not bot_target.dead:
  var aim=bot_target.position+Vector3(0,bot_aim_height-(.42 if bot_target.crouched else 0.0),0)-eye()
  var desired_yaw=atan2(-aim.x,-aim.z)+bot_error.x
  yaw=lerp_angle(yaw,desired_yaw,1-exp(-dt*14))
  pitch=lerpf(pitch,atan2(aim.y,Vector2(aim.x,aim.z).length())+bot_error.y,1-exp(-dt*14))
  ads=true;sprinting=false;crouched=health<40
  if health<45 and cover_time<=0:choose_cover(bot_target)
  if cover_time>0:
   follow_route(dt,false)
   crouched=move_wish.length_squared()<.1
  else:move_wish=Vector2(sin(bot_age*1.8+id)*.33,.4 if aim.length()<6 else (-.25 if aim.length()>23 else 0.0))
  if bot_reaction<=0 and bot_pause<=0 and absf(angle_difference(yaw,desired_yaw))<.07:
   var count=ammo[weapon_id];shoot()
   if ammo[weapon_id]<count:
    bot_burst-=1
    if bot_burst<=0:bot_pause=randf_range(.12,.27);bot_burst=randi_range(3,6)
  if ammo[weapon_id]==0:start_reload()
  if grenades>0 and aim.length()>10 and cover_time<=0 and randf()<dt*.06:throw_grenade()
 else:
  ads=false;crouched=false;sprinting=cover_time<=0
  follow_route(dt)
 if global_position.distance_to(last_position)<dt*.25 and move_wish.length()>.7 and (not is_instance_valid(bot_target) or cover_time>0):stuck_time+=dt
 else:stuck_time=0
 last_position=global_position
 if stuck_time>1.1:
  if game.bot_test and game.test_recoveries.size()<80:game.test_recoveries.append({'actor':id,'position':str(position),'waypoint':str(path[path_index]) if path_index<path.size() else 'none','cover':cover_time>0})
  recoveries+=1;cover_time=0;bot_target=null;bot_think=0;stuck_time=0
  set_route(Vector3([-20.0,0.0,20.0].pick_random(),0,randf_range(-24,24)))
 if not rewards.is_empty():activate_streak()
func apply_remote_input():
 move_wish=Vector2(network_input.get('x',0),network_input.get('z',0)).limit_length(1.0);yaw=network_input.get('yaw',yaw);pitch=clampf(network_input.get('pitch',pitch),-1.45,1.45);ads=network_input.get('ads',false);sprinting=network_input.get('sprint',false);crouched=network_input.get('crouch',false)
 var held=network_input.get('jump',false)
 if held and not remote_jump_held and is_on_floor():velocity.y=5.7
 remote_jump_held=held

func choose_cover(enemy: Fighter):
 var best=9.0
 for rect in game.arena.obstacles:
  var center=rect.get_center();var from_enemy=(center-Vector2(enemy.position.x,enemy.position.z)).normalized()
  var point=center+from_enemy*(rect.size.length()*.5+.8)
  var candidate=Vector3(point.x,global_position.y,point.y)
  var d=global_position.distance_to(candidate)
  if d<best and d>1:
   var q=PhysicsRayQueryParameters3D.create(enemy.eye(),candidate+Vector3.UP*1.0,1)
   if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
    var route=game.arena.route(global_position,candidate)
    if route.size()>1 and route.size()<16:best=d;cover_point=candidate;cover_time=2.5;path=route;path_index=0
