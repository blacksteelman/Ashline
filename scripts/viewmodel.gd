class_name WeaponView
extends RefCounted
var gun: Node3D
var magazine: Node3D
var support: Node3D
var sleeve: Node3D
var bolt: Node3D
var rest: Dictionary={}
var recoil_position=Vector3.ZERO
var recoil_velocity=Vector3.ZERO
var recoil_angle=Vector3.ZERO
var angle_velocity=Vector3.ZERO
var aim_blend=0.0
var equip_blend=0.0
var reload_stage=-1
func bind(node: Node3D):
 gun=node;rest.clear()
 magazine=gun.find_child('MagazineRig',true,false)
 support=gun.find_child('LeftHand',true,false)
 sleeve=gun.find_child('LeftSleeve',true,false)
 bolt=gun.find_child('Bolt carrier',true,false)
 for part in [magazine,support,sleeve,bolt]:
  if part:rest[part.get_instance_id()]=part.transform
 recoil_position=Vector3.ZERO;recoil_velocity=Vector3.ZERO;recoil_angle=Vector3.ZERO;angle_velocity=Vector3.ZERO;equip_blend=0;reload_stage=-1
func fire(kind: int):
 recoil_velocity+=Vector3(.045 if kind%2==0 else -.03,.08,[1.65,1.16,2.3,1.9][kind])
 angle_velocity+=Vector3([1.2,.85,1.75,1.4][kind],.15,.24 if kind%2==0 else -.18)
func spring_step(dt: float):
 # Critically damped analytic spring: consistent at varying render rates.
 var frequency=19.0
 var decay=exp(-frequency*dt)
 var c=recoil_velocity+recoil_position*frequency
 recoil_position=(recoil_position+c*dt)*decay
 recoil_velocity=(recoil_velocity-c*frequency*dt)*decay
 c=angle_velocity+recoil_angle*frequency
 recoil_angle=(recoil_angle+c*dt)*decay
 angle_velocity=(angle_velocity-c*frequency*dt)*decay
func update(owner: Fighter, dt: float):
 if not is_instance_valid(gun):return
 spring_step(dt)
 equip_blend=minf(1,equip_blend+dt*5)
 var aim=owner.ads and not owner.sprinting and owner.reload_left<=0
 aim_blend=move_toward(aim_blend,1 if aim else 0,dt*(7.5 if aim else 10.0))
 var smooth_aim=smoothstep(0,1,aim_blend)
 var position=Vector3(.185,-.185,-.38).lerp(Vector3(0,[-.102,-.102,-.126,-.085][owner.weapon_id],-.29),smooth_aim)
 var angles=Vector3.ZERO
 position=position.lerp(Vector3(.18,-.26,-.31),owner.sprint_blend);angles=Vector3(-.08,-.40,-.30)*owner.sprint_blend
 var movement=clampf(Vector2(owner.velocity.x,owner.velocity.z).length()/5,0,1)
 var bob=Vector3(sin(owner.walk_phase)*.009,cos(owner.walk_phase*2)*.005,0)*movement*(1-smooth_aim*.85)
 position+=bob+recoil_position*(1-smooth_aim*.42)+Vector3(0,-owner.landing,0)
 angles+=recoil_angle*(1-smooth_aim*.52)+Vector3(owner.sway.y,-owner.sway.x,owner.move_wish.x*-.02)
 position.y-=(1-equip_blend)*.13;angles.x+=(1-equip_blend)*.22
 # Near-wall retraction checks the same physical geometry as bullet impacts.
 var ray=PhysicsRayQueryParameters3D.create(owner.eye(),owner.eye()+owner.aim_dir()*.9,1)
 var hit=owner.get_world_3d().direct_space_state.intersect_ray(ray)
 if not hit.is_empty():
  var proximity=1-owner.eye().distance_to(hit.position)/.9
  position.z+=proximity*.22;angles.x+=proximity*.3
 for part in [magazine,support,sleeve,bolt]:
  if part:part.transform=rest[part.get_instance_id()]
 if bolt:bolt.position.z+=recoil_position.z*.38
 if owner.reload_left>0:
  var duration=Arsenal.WEAPONS[owner.weapon_id].reload*(.78 if owner.class_id==0 else 1.0)
  var progress=clampf(1-owner.reload_left/duration,0,1)
  var tilt=sin(progress*PI)
  position+=Vector3(-.035,.07,-.02)*tilt;angles+=Vector3(.16,-.16,-.45)*tilt
  var removed=smoothstep(.15,.33,progress)*(1-smoothstep(.60,.82,progress))
  if magazine:magazine.position+=Vector3(-.07,-.15,.04)*removed;magazine.rotation.z-=removed*.06
  var reach=smoothstep(.04,.18,progress)*(1-smoothstep(.83,.98,progress))
  if support:
   support.position+=Vector3(0,-.048,.205)*reach+Vector3(-.07,-.15,.04)*removed
  if sleeve:sleeve.position+=Vector3(-.03,-.12,.17)*reach
  var stage=-1 if progress<.14 else (0 if progress<.68 else (1 if progress<.90 else 2))
  if stage!=reload_stage:
   reload_stage=stage
   if stage>=0:owner.game.sound(['mag_out','mag_in','bolt'][stage],owner.eye(),owner.local_player,-10)
 else:reload_stage=-1
 gun.position=gun.position.lerp(position,1-exp(-dt*26))
 gun.rotation=gun.rotation.lerp(angles,1-exp(-dt*28))
