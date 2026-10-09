class_name FirstPersonRig
extends RefCounted
# First-person arms + weapon authored by tools/build_viewmodels.py.
# Baked clips (idle, draw, sprint, reload, reload_empty, cycle) run in an
# AnimationTree; recoil, sway, bob, ADS alignment and wall push are procedural
# on the scene root so they react at render rate.
const ADS_DISTANCE=[.105,.115,.075,.20]
var gun: Node3D
var skeleton: Skeleton3D
var tree: AnimationTree
var player: AnimationPlayer
var sight_rest=Transform3D.IDENTITY
var muzzle: Node3D
var ejector: Node3D
var bolt_modifier: SkeletonModifier3D
var recoil_position=Vector3.ZERO
var recoil_velocity=Vector3.ZERO
var recoil_angle=Vector3.ZERO
var angle_velocity=Vector3.ZERO
var aim_blend=0.0
var equip_blend=1.0
var sprint_weight=0.0
var inertia=Vector2.ZERO
var inertia_velocity=Vector2.ZERO
var action=''
var action_time=0.0
var action_length=0.0
var reload_stage=-1
var kick_bolt=0.0
var last_ammo=-1
var breath=0.0

const CAMO=['multicam','emr','mm14']
static func camo_texture(team: int, choice: int) -> Texture2D:
 # 0 = team issue (Aegis MultiCam-style, Ember EMR-style), 1..3 explicit pattern.
 var key=CAMO[choice-1] if choice>0 else ('multicam' if team==0 else 'emr')
 return load('res://assets/textures/camo_'+key+'_albedo.jpg')

func dress(team: int, choice: int):
 var tex=camo_texture(team,choice)
 for mi in gun.find_children('*','MeshInstance3D',true,false):
  for i in range(mi.mesh.get_surface_count()):
   var m=mi.get_surface_override_material(i)
   if m is ShaderMaterial and m.resource_name.begins_with('Sleeves'):
    var own: ShaderMaterial=m.duplicate();own.set_shader_parameter('albedo_tex',tex);mi.set_surface_override_material(i,own)

static func available(kind: int) -> bool:
 return ResourceLoader.exists(path(kind))
static func path(kind: int) -> String:
 return 'res://assets/viewmodels/vm_'+Arsenal.WEAPONS[kind].model+'.glb'

func bind(node: Node3D):
 gun=node
 skeleton=gun.find_child('Skeleton3D',true,false)
 player=gun.find_child('AnimationPlayer',true,false)
 muzzle=gun.find_child('Muzzle',true,false);ejector=gun.find_child('Ejector',true,false)
 var sight=gun.find_child('Sight',true,false)
 if skeleton:skeleton.reset_bone_poses()
 if sight:
  # Sight pose relative to the scene root at the rest (= hip) pose.
  var t=Transform3D.IDENTITY;var n: Node=sight
  while n and n!=gun:
   if n is Node3D:t=n.transform*t
   n=n.get_parent()
  var attach=sight.get_parent()
  if attach is BoneAttachment3D and skeleton:
   t=skeleton.transform*skeleton.get_bone_global_rest(skeleton.find_bone(attach.bone_name))*sight.transform
  sight_rest=t
 build_tree()
 bolt_modifier=load('res://scripts/bolt_modifier.gd').new();bolt_modifier.rig=self;skeleton.add_child(bolt_modifier)
 recoil_position=Vector3.ZERO;recoil_velocity=Vector3.ZERO;recoil_angle=Vector3.ZERO;angle_velocity=Vector3.ZERO
 play_action('draw',1.0)

func build_tree():
 tree=AnimationTree.new();gun.add_child(tree);tree.anim_player=tree.get_path_to(player)
 var graph=AnimationNodeBlendTree.new();tree.tree_root=graph
 var idle=AnimationNodeAnimation.new();idle.animation='idle';graph.add_node('Idle',idle)
 var sprint=AnimationNodeAnimation.new();sprint.animation='sprint';graph.add_node('Sprint',sprint)
 graph.add_node('Run',AnimationNodeBlend2.new());graph.connect_node('Run',0,'Idle');graph.connect_node('Run',1,'Sprint')
 var act=AnimationNodeAnimation.new();act.animation='idle';graph.add_node('Action',act)
 graph.add_node('ActionClock',AnimationNodeTimeSeek.new());graph.connect_node('ActionClock',0,'Action')
 graph.add_node('Act',AnimationNodeBlend2.new());graph.connect_node('Act',0,'Run');graph.connect_node('Act',1,'ActionClock')
 graph.connect_node('output',0,'Act')
 for clip in player.get_animation_list():
  if clip in ['idle','sprint']:player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
 tree.active=true

func has_clip(clip: String) -> bool:return player and player.has_animation(clip)

func play_action(clip: String, duration: float):
 if not has_clip(clip):return
 action=clip;action_time=0.0
 var native=player.get_animation(clip).length
 action_length=native if duration<=0 else duration
 tree.tree_root.get_node('Action').animation=clip
 reload_stage=-1

func stop_action():action=''

func fire(kind: int):
 if Arsenal.WEAPONS[kind].get('bolt',false):play_action('cycle',.9)
 recoil_velocity+=Vector3(randf_range(-.012,.012),.02,[.9,.75,1.4,1.1][kind])
 angle_velocity+=Vector3([1.05,.8,1.6,1.3][kind],randf_range(-.25,.25),randf_range(-.35,.35))
 kick_bolt=1.0

func spring_step(dt: float):
 var frequency=18.0;var decay=exp(-frequency*dt)
 var c=recoil_velocity+recoil_position*frequency
 recoil_position=(recoil_position+c*dt)*decay;recoil_velocity=(recoil_velocity-c*frequency*dt)*decay
 c=angle_velocity+recoil_angle*frequency
 recoil_angle=(recoil_angle+c*dt)*decay;angle_velocity=(angle_velocity-c*frequency*dt)*decay

func update(owner: Fighter, dt: float):
 if not is_instance_valid(gun):return
 spring_step(dt)
 kick_bolt=move_toward(kick_bolt,0.0,dt*18.0)
 bolt_modifier.lock=1.0 if owner.ammo[owner.weapon_id]==0 and owner.reload_left<=0 and owner.weapon_id!=2 else 0.0
 var w=Arsenal.WEAPONS[owner.weapon_id]
 var reload_duration=w.reload*(.78 if owner.class_id==0 else 1.0)
 # Reload clip follows the authoritative timer, so animation and ammo agree.
 if owner.reload_left>0:
  var clip='reload_empty' if owner.ammo[owner.weapon_id]==0 and has_clip('reload_empty') else 'reload'
  if action!=clip:play_action(clip,reload_duration);action_time=reload_duration-owner.reload_left
  else:action_time=reload_duration-owner.reload_left
 elif action in ['reload','reload_empty']:stop_action()
 elif action!='':action_time+=dt
 if action!='' and action_time>=action_length:stop_action()
 var act_weight=1.0 if action!='' else 0.0
 tree.set('parameters/Act/blend_amount',act_weight)
 if action!='':
  var native=player.get_animation(action).length
  tree.set('parameters/ActionClock/seek_request',clampf(action_time/maxf(.01,action_length),0,1)*native)
  sounds(owner)
 sprint_weight=move_toward(sprint_weight,1.0 if owner.sprinting and action=='' else 0.0,dt*6.0)
 tree.set('parameters/Run/blend_amount',smoothstep(0,1,sprint_weight))
 # Aim-down-sights: carry the authored sight onto the view axis.
 var aim=owner.ads and not owner.sprinting and owner.reload_left<=0 and action==''
 aim_blend=move_toward(aim_blend,1.0 if aim else 0.0,dt*(6.5 if aim else 8.5))
 var a=smoothstep(0,1,aim_blend)
 var ads=Transform3D(Basis.IDENTITY,Vector3(0,0,-ADS_DISTANCE[owner.weapon_id]))*sight_rest.affine_inverse()
 # Mouse inertia: the weapon lags behind fast turns and settles with a soft spring.
 var target_inertia=owner.sway*(1.0-a*.7)
 inertia_velocity+=(target_inertia*6.0-inertia)*dt*90.0
 inertia_velocity*=exp(-dt*14.0);inertia+=inertia_velocity*dt
 breath+=dt
 var movement=clampf(Vector2(owner.velocity.x,owner.velocity.z).length()/5.0,0,1.6)*(1.0 if owner.is_on_floor() else .2)
 var phase=owner.walk_phase
 var bob=Vector3(sin(phase)*.011,-absf(cos(phase))*.008,0)*movement*(1-a*.88)
 var idle_sway=Vector3(sin(breath*1.1)*.0012,sin(breath*2.2)*.0009,0)*(1-a*.8)
 var offset=bob+idle_sway+recoil_position*Vector3(1,1,.06)*(1-a*.35)+Vector3(0,-owner.landing*1.3,0)
 var rot=Vector3(recoil_angle.x*.045,recoil_angle.y*.02,recoil_angle.z*.03)*(1-a*.55)
 rot+=Vector3(inertia.y*2.2+bob.y*2,-inertia.x*2.5,-inertia.x*1.6-owner.move_wish.x*.035*(1-a))
 # Near-wall retraction uses real collision.
 var ray=PhysicsRayQueryParameters3D.create(owner.eye(),owner.eye()+owner.aim_dir()*.75,1)
 var hit=owner.get_world_3d().direct_space_state.intersect_ray(ray)
 if not hit.is_empty():
  var push=1-owner.eye().distance_to(hit.position)/.75
  offset+=Vector3(0,-.03,.12)*push;rot+=Vector3(.35,.0,.15)*push*(1-a)
 var procedural=Transform3D(Basis.from_euler(rot),offset)
 gun.transform=Transform3D.IDENTITY.interpolate_with(ads,a)*procedural
 # Viewmodel field of view narrows slightly when aiming.
 ViewmodelMaterial.update_projection(lerpf(52.0,44.0,a),owner.camera.fov)

func sounds(owner: Fighter):
 # Mechanical sounds at the authored contact points of each clip.
 var marks={'reload':[.17,.6,.68],'reload_empty':[.15,.52,.71],'cycle':[.25,.55,.0]}
 if not marks.has(action):return
 var p=action_time/maxf(.01,action_length)
 var keys=['mag_out','mag_in','bolt']
 for i in range(3):
  if marks[action][i]>0 and p>=marks[action][i] and reload_stage<i:
   reload_stage=i;owner.game.sound(keys[i] if action!='cycle' else 'bolt',owner.eye(),true,-10)

func muzzle_position() -> Vector3:
 return muzzle.global_position if muzzle else gun.global_position
func ejector_position() -> Vector3:
 return ejector.global_position if ejector else gun.global_position
