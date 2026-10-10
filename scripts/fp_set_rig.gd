class_name FPSetRig
extends RefCounted
# First-person arms + weapon from the ccransh CC-BY sets (assets/viewmodels/fp_*/scene.gltf).
# The rig's Head_Cam bone is the authored camera: every frame the scene is placed so that bone
# sits on our camera, which reproduces the authored view including its camera motion.
# Loops (idle/walk/sprint) cross-fade by movement; draw/fire/reload play over them, reload synced
# to the gameplay timer. ADS is procedural: the measured sight line (rear -> front, attached to the
# weapon bone) is carried onto the view axis.
var gun: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var cfg: Dictionary
var cam_bone=-1
var weapon_bone=-1
var clips: Dictionary={}
var base=''
var action=''
var action_time=0.0
var action_length=0.0
var aim_blend=0.0
var equip_blend=1.0
var recoil_position=Vector3.ZERO
var recoil_velocity=Vector3.ZERO
var recoil_angle=Vector3.ZERO
var angle_velocity=Vector3.ZERO
var inertia=Vector2.ZERO
var inertia_velocity=Vector2.ZERO
var breath=0.0
var reload_stage=-1
var muzzle_local=Vector3.ZERO
var view_fix=Basis.IDENTITY

const WORDS={'idle':['Idle'],'walk':['Walk'],'sprint':['Run'],'draw':['Draw'],'fire':['Shot_nosight','Shoot','Shot','Fire','OneShot'],
 'fire_ads':['Shot_sight'],'reload':['Reload_Fast','Reload_fast','Reload_easy','AK_Reload','SRifle_Reload','Reload'],'reload_empty':['Reload_full','Reload_Full'],'inspect':['inspect','Ispect']}

# Some sets weight a few stray vertices to the rig's root joint, or to nothing (a thin line to the origin):
# drop the triangles that use them. Cached per mesh resource.
static var cleaned: Dictionary={}
static func strip_strays(mi: MeshInstance3D):
 var mesh: ArrayMesh=mi.mesh
 if not mesh or not mi.skin:return
 if cleaned.has(mesh):mi.mesh=cleaned[mesh];return
 var root_binds={}
 for b in mi.skin.get_bind_count():
  var name=String(mi.skin.get_bind_name(b))
  var sk=mi.get_node_or_null(mi.skeleton) as Skeleton3D
  if name=='' and sk and mi.skin.get_bind_bone(b)>=0:name=sk.get_bone_name(mi.skin.get_bind_bone(b))
  if name.begins_with('_rootJoint') or name.begins_with('GLTF_created'):root_binds[b]=true
 var surfaces=[];var changed=false
 for s in mesh.get_surface_count():
  var arrays=mesh.surface_get_arrays(s);var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
  var count=arrays[Mesh.ARRAY_VERTEX].size();var per=bones.size()/maxi(1,count)
  var stray=PackedByteArray();stray.resize(count)
  for v in count:
   var w=0.0;var total=0.0
   for k in per:
    total+=weights[v*per+k]
    if root_binds.has(bones[v*per+k]):w+=weights[v*per+k]
   if w>=.5 or total<.01:stray[v]=1
  var idx: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  if idx.size()>0 and stray.count(1)>0:
   var keep=PackedInt32Array()
   for t in range(0,idx.size(),3):
    if stray[idx[t]]==0 and stray[idx[t+1]]==0 and stray[idx[t+2]]==0:keep.append_array([idx[t],idx[t+1],idx[t+2]])
   arrays[Mesh.ARRAY_INDEX]=keep;changed=true
  for c in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]:arrays[c]=null
  surfaces.append(arrays)
 if not changed:cleaned[mesh]=mesh;return
 var out=ArrayMesh.new()
 for s in mesh.get_surface_count():
  var flags=mesh.surface_get_format(s)&(Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS|Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
  out.add_surface_from_arrays(mesh.surface_get_primitive_type(s),surfaces[s],[],{},flags)
  out.surface_set_material(s,mesh.surface_get_material(s))
 cleaned[mesh]=out if changed else mesh
 mi.mesh=cleaned[mesh]

static func available(kind: int) -> bool:
 return Arsenal.WEAPONS[kind].has('fp') and ResourceLoader.exists(path(kind))
static func path(kind: int) -> String:
 return 'res://assets/viewmodels/'+Arsenal.WEAPONS[kind].fp.set+'/scene.gltf'

func bind(node: Node3D, kind: int=-1):
 gun=node
 cfg=Arsenal.WEAPONS[kind].fp if kind>=0 else {}
 skeleton=gun.find_child('Skeleton3D',true,false)
 player=gun.find_child('AnimationPlayer',true,false)
 var ico=gun.find_child('Icosphere',true,false)
 if ico:ico.visible=false
 for mi in gun.find_children('*','MeshInstance3D',true,false):strip_strays(mi)
 for i in skeleton.get_bone_count():
  var n=skeleton.get_bone_name(i)
  if n.begins_with('Head_Cam') and not '_end' in n:cam_bone=i
  if n.begins_with(cfg.get('bone','~')) and not '_end' in n:weapon_bone=i
 for key in WORDS:
  for word in WORDS[key]:
   if clips.has(key):break
   for a in player.get_animation_list():
    if word in String(a) and not (key=='reload' and ('full' in String(a) or 'Full' in String(a))):clips[key]=a;break
 for loop in ['idle','walk','sprint']:
  if clips.has(loop):player.get_animation(clips[loop]).loop_mode=Animation.LOOP_LINEAR
 view_fix=axes_basis(cfg.get('fwd','+z'),cfg.get('up','+y'))
 muzzle_local=cfg.get('muzzle',Vector3.ZERO)
 player.playback_default_blend_time=.18
 set_base('idle')
 if clips.has('draw'):play_action('draw',-1)

# Columns of the camera bone that look forward / up, as a basis whose -Z is forward.
static func axes_basis(fwd: String, up: String) -> Basis:
 var axis=func(label: String) -> Vector3:
  var v={'x':Vector3.RIGHT,'y':Vector3.UP,'z':Vector3.BACK}[label[1]]
  return v if label[0]=='+' else -v
 var f: Vector3=axis.call(fwd);var u: Vector3=axis.call(up)
 return Basis(u.cross(-f).normalized(),u,-f)

# Where the eye really is relative to the rig's camera bone (view axes, scene units):
# cam_offset moves it, cam_rot (degrees, pitch/yaw/roll) turns the view.
static func eye_fix(c: Dictionary) -> Transform3D:
 return Transform3D(Basis.from_euler(c.get('cam_rot',Vector3.ZERO)*PI/180.0),c.get('cam_offset',Vector3.ZERO))

# Moves the sight line (rear/front in the barrel frame wb) onto the view axis, eye metres behind the rear sight;
# ads_roll (degrees) levels a set whose barrel frame is canted.
static func ads_offset(c: Dictionary, wb: Transform3D) -> Transform3D:
 var rear=wb*c.rear;var front=wb*c.front
 var basis=Basis.looking_at(front-rear,wb.basis.y.normalized())*Basis(Vector3.BACK,deg_to_rad(c.get('ads_roll',0.0)))
 return Transform3D(Basis.IDENTITY,Vector3(0,0,-c.get('eye',.15)))*Transform3D(basis,rear).affine_inverse()

func dress(_team: int,_choice: int):pass

# The sets share one arms texture (olive jacket, brown leather gloves); swap in the team's sleeve camo and gloves
# so the hands match the soldier models (tools/paint_fp_arms.py). Call before ViewmodelMaterial.apply.
const TEAM_ARMS=['res://assets/viewmodels/arms_aegis_albedo.jpg','res://assets/viewmodels/arms_ember_albedo.jpg']
static var dressed_arms: Dictionary={}
static func dress_arms(root: Node, team: int):
 var path=TEAM_ARMS[clampi(team,0,TEAM_ARMS.size()-1)]
 if not ResourceLoader.exists(path):return
 for mi in root.find_children('*','MeshInstance3D',true,false):
  if not mi.mesh:continue
  for i in mi.mesh.get_surface_count():
   var source=mi.mesh.surface_get_material(i)
   if not source is BaseMaterial3D or source.resource_name!='arms':continue
   var key=[source,team]
   if not dressed_arms.has(key):
    var m: BaseMaterial3D=source.duplicate();m.albedo_texture=load(path);m.albedo_color=Color.WHITE
    dressed_arms[key]=m
   mi.set_surface_override_material(i,dressed_arms[key])

func has_clip(clip: String) -> bool:return clips.has(clip)

func set_base(clip: String):
 if not clips.has(clip):clip='idle' if clip!='sprint' or not clips.has('walk') else 'walk'
 if base==clip:return
 base=clip
 if action=='':player.play(clips[base],.22)

func play_action(clip: String, duration: float):
 if not clips.has(clip):return
 action=clip;action_time=0.0;reload_stage=-1
 var native=player.get_animation(clips[clip]).length
 action_length=native if duration<=0 else duration
 player.play(clips[clip],.06,native/action_length)

func stop_action():
 action=''
 if clips.has(base):player.play(clips[base],.2)

func fire(kind: int):
 var w=Arsenal.WEAPONS[kind]
 if w.get('bolt',false):play_action('fire_ads' if aim_blend>.5 and clips.has('fire_ads') else 'fire',w.interval*.95)
 elif clips.has('fire'):play_action('fire',-1)
 var k=w.get('kick',1.0)
 recoil_velocity+=Vector3(randf_range(-.01,.01),.012,.75)*k
 angle_velocity+=Vector3(.9,randf_range(-.2,.2),randf_range(-.3,.3))*k

# Exact integration of the existing recoil response. Keeping damping inside the
# solution avoids a different kick at each render rate or a frozen tail after a hitch.
static func recoil_state(position: Vector3, velocity: Vector3, stiffness: float, damping: float, dt: float) -> Array:
 var half_trace=(12.0+damping)*.5
 var diagonal=(damping-12.0)*.5
 var frequency=sqrt(diagonal*diagonal-.06*stiffness)
 var fast=exp((-half_trace-frequency)*dt)
 var slow=exp((-half_trace+frequency)*dt)
 var even=(slow+fast)*.5
 var odd=(slow-fast)/(2.0*frequency)
 return [position*even+(position*diagonal+velocity*.06)*odd,
         velocity*even+(-position*stiffness-velocity*diagonal)*odd]

func spring_step(dt: float):
 if dt<=0 or not is_finite(dt):return
 var linear=recoil_state(recoil_position,recoil_velocity,240.0,22.0,dt)
 recoil_position=linear[0];recoil_velocity=linear[1]
 var angular=recoil_state(recoil_angle,angle_velocity,260.0,24.0,dt)
 recoil_angle=angular[0];angle_velocity=angular[1]

# Damped spring towards mouse inertia; analytic so a hitch cannot fling the
# weapon across the screen. The same target over the same time gives the same pose.
func inertia_step(target: Vector2, dt: float):
 if dt<=0 or not is_finite(dt):return
 var frequency=sqrt(41.0)
 var decay=exp(-7.0*dt)
 var cosine=cos(frequency*dt)
 var sine=sin(frequency*dt)/frequency
 var offset=inertia-target*6.0
 var speed=inertia_velocity
 inertia=target*6.0+decay*(offset*cosine+(speed+offset*7.0)*sine)
 inertia_velocity=decay*(speed*cosine-(speed*7.0+offset*90.0)*sine)

# Skeleton transform in the imported scene root's space.
func skeleton_in_root() -> Transform3D:
 var n: Node=skeleton
 var chain=skeleton.transform
 n=skeleton.get_parent()
 while n and n!=gun:
  if n is Node3D:chain=n.transform*chain
  n=n.get_parent()
 return chain

func bone_in_root(bone: int) -> Transform3D:
 return skeleton_in_root()*skeleton.get_bone_global_pose(bone)

func camera_in_root() -> Transform3D:
 # The sniper set has no Head_Cam joint. Its framing offsets were authored
 # relative to the rig origin; declare that explicitly instead of querying -1.
 if cfg.get('camera_anchor','bone')=='rig_origin':return skeleton_in_root()
 return bone_in_root(cam_bone)

func update(owner: Fighter, dt: float):
 if not is_instance_valid(gun):return
 spring_step(dt)
 var w=Arsenal.WEAPONS[owner.weapon_id]
 var reload_duration=owner.reload_time(owner.weapon_id)
 if owner.reload_left>0:
  var clip='reload_empty' if owner.ammo[owner.weapon_id]==0 and clips.has('reload_empty') else 'reload'
  if action!=clip:play_action(clip,reload_duration)
  action_time=reload_duration-owner.reload_left
  var native=player.get_animation(clips[clip]).length
  var expected=clampf(action_time/maxf(.01,reload_duration),0,1)*native
  if absf(player.current_animation_position-expected)>.08:player.seek(expected,true)
 elif action in ['reload','reload_empty']:stop_action()
 elif action!='':action_time+=dt
 if action!='' and action_time>=action_length:stop_action()
 sounds(owner)
 # Loops by movement.
 var speed=Vector2(owner.velocity.x,owner.velocity.z).length()
 var aim=owner.ads and not owner.sprinting and owner.reload_left<=0 and action in ['','fire','fire_ads']
 if owner.sprinting and speed>1:set_base('sprint')
 elif speed>.8 and owner.is_on_floor() and not aim:set_base('walk')
 else:set_base('idle')
 if action=='' and clips.has(base):player.speed_scale=clampf(speed/4.5,.7,1.3) if base!='idle' else 1.0
 elif action!='':player.speed_scale=1.0
 aim_blend=move_toward(aim_blend,1.0 if aim else 0.0,dt*(6.0 if aim else 8.0))
 var a=smoothstep(0,1,aim_blend)
 # Authored camera -> our camera.
 var s=cfg.get('scale',1.0)
 var cam=camera_in_root();cam.basis=cam.basis.orthonormalized()*view_fix
 var align=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*s),Vector3.ZERO)*eye_fix(cfg).affine_inverse()*cam.affine_inverse()
 # ADS: sight line (weapon-bone frame) onto the view axis.
 var ads=Transform3D.IDENTITY
 if a>0 and weapon_bone>=0 and cfg.has('rear'):
  ads=ads_offset(cfg,align*bone_in_root(weapon_bone)*cfg.frame)
 # Procedural feel.
 var target_inertia=owner.sway*(1.0-a*.7)
 inertia_step(target_inertia,dt)
 breath+=dt
 var offset=recoil_position*Vector3(1,1,.08)*(1-a*.4)+Vector3(0,-owner.landing*1.3,0)+Vector3(sin(breath*1.1)*.0008,sin(breath*2.2)*.0006,0)*(1-a)
 var rot=Vector3(recoil_angle.x*.04,recoil_angle.y*.02,recoil_angle.z*.03)*(1-a*.5)
 rot+=Vector3(inertia.y*2.0,-inertia.x*2.3,-inertia.x*1.4-owner.move_wish.x*.03*(1-a))
 var ray=PhysicsRayQueryParameters3D.create(owner.eye(),owner.eye()+owner.aim_dir()*.75,1)
 var hit=owner.get_world_3d().direct_space_state.intersect_ray(ray)
 if not hit.is_empty():
  var push=1-owner.eye().distance_to(hit.position)/.75
  offset+=Vector3(0,-.03,.10)*push;rot+=Vector3(.3,0,.12)*push*(1-a)
 var procedural=Transform3D(Basis.from_euler(rot),offset)
 gun.transform=Transform3D.IDENTITY.interpolate_with(ads,a)*procedural*align
 ViewmodelMaterial.update_projection(lerpf(cfg.get('fov',50.0),cfg.get('fov_ads',40.0),a),owner.camera.fov)

func sounds(owner: Fighter):
 var marks={'reload':[.2,.62,.0],'reload_empty':[.15,.5,.78]}
 if not marks.has(action):return
 var p=action_time/maxf(.01,action_length)
 var keys=['mag_out','mag_in','bolt']
 for i in range(3):
  if marks[action][i]>0 and p>=marks[action][i] and reload_stage<i:
   reload_stage=i;owner.game.sound(keys[i],owner.eye(),true,-10)

func muzzle_position() -> Vector3:
 if weapon_bone<0 or not cfg.has('frame'):return gun.global_position
 var wb=gun.global_transform*bone_in_root(weapon_bone)*cfg.frame
 return wb*muzzle_local
func ejector_position() -> Vector3:
 if weapon_bone<0 or not cfg.has('frame'):return gun.global_position
 var wb=gun.global_transform*bone_in_root(weapon_bone)*cfg.frame
 return wb*cfg.get('ejector',muzzle_local*.3)
