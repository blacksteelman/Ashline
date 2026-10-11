class_name CharacterMotion
extends RefCounted
# Presentation only: the server's capsule, damage and movement remain authoritative.
var actor: Fighter
var skeleton: Skeleton3D
var tree: AnimationTree
var anchor: BoneAttachment3D
var clips: Dictionary={}
var death_age=0.0
var was_dead=false
var previous_position=Vector3.ZERO
var rendered_velocity=Vector3.ZERO
var reload_blend=0.0
var crouch_blend=0.0
var air_blend=0.0
var air_age=0.0
var sprint_blend=0.0
var graphical=false
var ragdoll: CharacterRagdoll
var grip: GripIK
var ref_walk=1.7
var ref_sprint=2.46
var ref_crouch=.95
func bind(fighter: Fighter) -> bool:
 actor=fighter
 skeleton=actor.model.find_child('Skeleton3D',true,false)
 var player=actor.model.find_child('AnimationPlayer',true,false) as AnimationPlayer
 if not skeleton or not player or skeleton.find_bone('Chest')<0:return false
 if skeleton.find_bone('Weapon')>=0:ref_walk=5.1;ref_sprint=7.8;ref_crouch=2.5
 for role in ['Idle','Forward','Backward','Left','Right','Sprint','CrouchIdle','CrouchWalk','Jump','Reload','Death']:
  for name in player.get_animation_list():
   if String(name).get_file().begins_with(role):clips[role]=name;break
  if not clips.has(role):push_error('Missing biped clip: '+role);return false
  if role not in ['Jump','Reload','Death']:player.get_animation(clips[role]).loop_mode=Animation.LOOP_LINEAR
 player.stop()
 tree=AnimationTree.new();actor.model.add_child(tree);tree.anim_player=tree.get_path_to(player)
 var graph=AnimationNodeBlendTree.new();tree.tree_root=graph
 var movement=AnimationNodeBlendSpace2D.new();movement.min_space=Vector2(-1,-1);movement.max_space=Vector2.ONE
 for point in [['Idle',Vector2.ZERO],['Forward',Vector2(0,-1)],['Backward',Vector2(0,1)],['Left',Vector2(-1,0)],['Right',Vector2(1,0)]]:
  movement.add_blend_point(animation(point[0]),point[1])
 graph.add_node('Movement',movement)
 var cadence=AnimationNodeTimeScale.new();graph.add_node('Cadence',cadence);graph.connect_node('Cadence',0,'Movement')
 graph.add_node('Sprint',animation('Sprint'));graph.add_node('SprintCadence',AnimationNodeTimeScale.new());graph.connect_node('SprintCadence',0,'Sprint');blend(graph,'Fast','Cadence','SprintCadence')
 var crouch=AnimationNodeBlendSpace1D.new();crouch.min_space=0;crouch.max_space=1;crouch.add_blend_point(animation('CrouchIdle'),0);crouch.add_blend_point(animation('CrouchWalk'),1);graph.add_node('Crouch',crouch)
 graph.add_node('CrouchCadence',AnimationNodeTimeScale.new());graph.connect_node('CrouchCadence',0,'Crouch');blend(graph,'Low','Fast','CrouchCadence')
 graph.add_node('Jump',animation('Jump'));graph.add_node('AirClock',AnimationNodeTimeSeek.new());graph.connect_node('AirClock',0,'Jump');blend(graph,'Air','Low','AirClock')
 graph.add_node('Reload',animation('Reload'));graph.add_node('ReloadClock',AnimationNodeTimeSeek.new());graph.connect_node('ReloadClock',0,'Reload')
 var reload_node=AnimationNodeBlend2.new();reload_node.filter_enabled=true
 var reload_clip=player.get_animation(clips.Reload)
 for track in range(reload_clip.get_track_count()):
  var path=reload_clip.track_get_path(track)
  if path.get_subname_count()>0 and reload_bone(skeleton,String(path.get_subname(0))):reload_node.set_filter_path(path,true)
 graph.add_node('Service',reload_node);graph.connect_node('Service',0,'Air');graph.connect_node('Service',1,'ReloadClock')
 graph.add_node('Death',animation('Death'));graph.add_node('DeathClock',AnimationNodeTimeSeek.new());graph.connect_node('DeathClock',0,'Death')
 blend(graph,'Down','Service','DeathClock');graph.connect_node('output',0,'Down')
 anchor=BoneAttachment3D.new();anchor.name='WeaponAnchor';anchor.bone_name='Chest';skeleton.add_child(anchor)
 var aim=load('res://scripts/character_aim.gd').new();aim.actor=actor;skeleton.add_child(aim)
 ragdoll=CharacterRagdoll.new();ragdoll.active=false;skeleton.add_child(ragdoll)
 previous_position=actor.global_position;graphical=DisplayServer.get_name()!='headless';tree.active=graphical
 return true
static func reload_bone(sk: Skeleton3D, name: String) -> bool:
 # The tilted weapon and both arm chains must use the same reload pose.
 # Include fingers and shoulder joints without replacing locomotion in the torso/legs.
 if name=='Weapon':return true
 var index=sk.find_bone(name)
 while index>=0:
  if sk.get_bone_name(index) in ['UpperArm.L','UpperArm.R','LeftShoulder','RightShoulder']:return true
  index=sk.get_bone_parent(index)
 return false
func animation(role: String) -> AnimationNodeAnimation:
 var node=AnimationNodeAnimation.new();node.animation=clips[role];return node
func blend(graph: AnimationNodeBlendTree, name: String, a: String,b: String):
 graph.add_node(name,AnimationNodeBlend2.new());graph.connect_node(name,0,a);graph.connect_node(name,1,b)
func attach_weapon(gun: Node3D):
 if not anchor or actor.model.find_child('WeaponSocket',true,false):return
 var rest=actor.model.global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_rest(skeleton.find_bone('Chest'))
 gun.reparent(anchor,false)
 gun.transform=rest.affine_inverse()*Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.8),Vector3(.13,1.17,-.37))
func reset():
 if ragdoll:ragdoll.stop()
 if is_instance_valid(actor.world_gun):actor.world_gun.visible=true
 grip=actor.model.find_child('GripIK',true,false)
 if grip:grip.active=true
 death_age=0;was_dead=false;previous_position=actor.global_position;rendered_velocity=Vector3.ZERO
 sprint_blend=0;reload_blend=0;crouch_blend=0;air_blend=0;air_age=0
 if tree:tree.set('parameters/Down/blend_amount',0.0)
func update(dt: float):
 if not tree:return
 # Dedicated servers and automated headless clients need no pose evaluation.
 # The hidden local body is animated again when shown during death.
 if not graphical:return
 if actor.dead:
  if not ragdoll.running:
   tree.active=true;tree.advance(0)
   grip=actor.model.find_child('GripIK',true,false)
   if grip:grip.active=false
   tree.active=false
   ragdoll.start(actor.game,actor.velocity,actor.last_hit_direction,actor.last_hit_zone)
   ragdoll.drop_weapon(actor.world_gun,actor.velocity,actor.last_hit_direction)
  return
 tree.active=not actor.local_player
 if not tree.active:return
 var remote=not actor.game.authority() and not actor.local_player
 var displacement=actor.global_position-previous_position;previous_position=actor.global_position
 var velocity=actor.velocity
 if remote:
  var inferred=displacement/maxf(.001,dt)
  if displacement.length()>2:inferred=Vector3.ZERO
  rendered_velocity=rendered_velocity.lerp(inferred,1-exp(-dt*14));velocity=rendered_velocity
 var local=velocity.rotated(Vector3.UP,-actor.rotation.y)
 var speed=Vector2(local.x,local.z).length()
 var moving=Vector2(local.x,local.z)/maxf(1.0,speed)
 tree.set('parameters/Movement/blend_position',moving*minf(1,speed/1.0))
 # Clip reference speeds: Forward/Backward/strafe 5.1, Sprint 7.8, CrouchWalk 2.5 (dressed soldiers).
 tree.set('parameters/Cadence/scale',clampf(speed/ref_walk,.6,2.9) if speed>.2 else 1.0)
 var sprint_target=clampf((speed-6.0)/1.8,0,1) if (remote or actor.sprinting) and actor.reload_left<=0 and not actor.crouched else 0.0
 sprint_blend=lerpf(sprint_blend,sprint_target,1-exp(-dt*12))
 tree.set('parameters/Fast/blend_amount',sprint_blend)
 tree.set('parameters/SprintCadence/scale',clampf(speed/ref_sprint,.8,3.6))
 crouch_blend=move_toward(crouch_blend,1.0 if actor.crouched else 0.0,dt*9)
 tree.set('parameters/Low/blend_amount',crouch_blend);tree.set('parameters/Crouch/blend_position',minf(1,speed/.8))
 tree.set('parameters/CrouchCadence/scale',clampf(speed/ref_crouch,.6,2.8) if speed>.2 else 1.0)
 var airborne=absf(velocity.y)>.5 if remote else not actor.is_on_floor()
 air_age=air_age+dt if airborne else 0.0;tree.set('parameters/AirClock/seek_request',minf(.799,air_age*1.25))
 air_blend=move_toward(air_blend,1.0 if airborne else 0.0,dt*10);tree.set('parameters/Air/blend_amount',air_blend)
 reload_blend=move_toward(reload_blend,1.0 if actor.reload_left>0 and not actor.dead else 0.0,dt*12)
 tree.set('parameters/Service/blend_amount',reload_blend)
 if actor.reload_left>0:
  var duration=actor.reload_time(actor.weapon_id)
  tree.set('parameters/ReloadClock/seek_request',clampf(1-actor.reload_left/duration,0,1)*2.0)
 if actor.dead:
  if not was_dead:death_age=0
  death_age+=dt;tree.set('parameters/DeathClock/seek_request',minf(.999,death_age))
 tree.set('parameters/Down/blend_amount',1.0 if actor.dead else 0.0);was_dead=actor.dead
 if actor.world_gun:
  var magazine=actor.world_gun.find_child('MagazineRig',true,false)
  if magazine:
   var t=clampf(1-actor.reload_left/(actor.reload_time(actor.weapon_id)),0,1)
   # Match the authored hand: extract, stow, fetch, insert (2-second source clip).
   var extraction=smoothstep(.21,.375,t)*(1.0-smoothstep(.65,.725,t)) if actor.reload_left>0 else 0.0
   magazine.position=Vector3(0,-.16,.09)*extraction
   magazine.visible=not (actor.reload_left>0 and t>=.375 and t<.475)
