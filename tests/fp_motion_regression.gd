extends SceneTree
# Tests the active Sketchfab rig, not the retired WeaponView spring.
var failed=0
var checks=0
func expect(ok: bool, message: String):
 checks+=1
 print('PASS ' if ok else 'FAIL ',message)
 if not ok:failed+=1
func seeded() -> FPSetRig:
 var rig=FPSetRig.new()
 rig.recoil_velocity=Vector3(.01,.012,.75)
 rig.angle_velocity=Vector3(.9,.2,-.3)
 return rig
func burst(rate: int) -> FPSetRig:
 var rig=FPSetRig.new()
 # Split steps at actual shot times: cadence must not drift with rendering.
 for shot in range(6):
  rig.recoil_velocity.z+=.75
  rig.angle_velocity.x+=.9
  var remaining=.08
  while remaining>0.00000001:
   var dt=minf(remaining,1.0/rate)
   rig.spring_step(dt);remaining-=dt
 return rig
func _initialize():
 var reference=seeded()
 reference.spring_step(.2)
 reference.inertia_step(Vector2(.02,-.02),.2)
 for rate in [15,30,60,144,240]:
  var rig=seeded()
  var remaining=.2
  while remaining>0.00000001:
   var dt=minf(remaining,1.0/rate)
   rig.spring_step(dt);rig.inertia_step(Vector2(.02,-.02),dt)
   remaining-=dt
  expect(rig.recoil_position.distance_to(reference.recoil_position)<.000001 and rig.recoil_velocity.distance_to(reference.recoil_velocity)<.00001,'Recoil response at %d FPS'%rate)
  expect(rig.recoil_angle.distance_to(reference.recoil_angle)<.000001 and rig.angle_velocity.distance_to(reference.angle_velocity)<.00001,'Angular recoil at %d FPS'%rate)
  expect(rig.inertia.distance_to(reference.inertia)<.000001 and rig.inertia_velocity.distance_to(reference.inertia_velocity)<.00001,'Mouse inertia at %d FPS'%rate)
 var burst_reference=burst(240)
 for rate in [15,30,60,144]:
  var rig=burst(rate)
  expect(rig.recoil_position.distance_to(burst_reference.recoil_position)<.000001 and rig.recoil_angle.distance_to(burst_reference.recoil_angle)<.000001,'Six-shot burst at %d FPS'%rate)
 var hitch=seeded()
 hitch.inertia=Vector2(.08,-.06);hitch.inertia_velocity=Vector2(.4,-.2)
 hitch.spring_step(2.0);hitch.inertia_step(Vector2.ZERO,2.0)
 expect(hitch.recoil_position.is_finite() and hitch.recoil_velocity.length()<.00001,'Recoil settles through a two-second hitch')
 expect(hitch.inertia.is_finite() and hitch.inertia.length()<.00001,'Hands settle through a two-second hitch')
 var rest=seeded();rest.spring_step(0);rest.inertia_step(Vector2.ONE,0)
 expect(rest.recoil_position==Vector3.ZERO and rest.inertia==Vector2.ZERO,'Paused frame does not move the weapon')
 var kick=seeded();kick.spring_step(.04)
 expect(kick.recoil_position.z>.0007 and kick.recoil_position.z<.0012,'Visible recoil impulse retained near its peak')
 print('FP_MOTION ',checks,' checks, ',failed,' failures')
 quit(0 if failed==0 else 1)
