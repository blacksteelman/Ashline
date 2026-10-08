extends SceneTree
var checks=0
var failures=0
func expect(ok: bool, message: String):
 if ok:checks+=1;print('PASS: ',message)
 else:failures+=1;push_error('FAIL: '+message)
func _initialize():call_deferred('run')
func triangles(node: Node3D) -> int:
 var total=0
 for mesh in node.find_children('*','MeshInstance3D',true,false):
  if not mesh.visible or mesh.is_queued_for_deletion():continue
  for index in mesh.mesh.get_surface_count():
   var arrays=mesh.mesh.surface_get_arrays(index)
   total+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
 return total
func run():
 # Regression for lost walls when combining indexed BoxMesh and unindexed ruin geometry.
 var fixture=Node3D.new();root.add_child(fixture)
 Art.box(fixture,Vector3.ZERO,Vector3(2,1,1),Art.mat('brick'))
 Art.box(fixture,Vector3(3,2,0),Vector3(5,4,.4),Art.mat('brick'),true)
 var before=triangles(fixture);StaticBatch.bake(fixture);await process_frame
 expect(triangles(fixture)==before,'Batching preserves every triangle across mixed index formats')
 fixture.queue_free();await process_frame
 var spring30=WeaponView.new();var spring144=WeaponView.new();spring30.fire(0);spring144.fire(0)
 for i in range(30):spring30.spring_step(1.0/30)
 for i in range(144):spring144.spring_step(1.0/144)
 expect(spring30.recoil_position.distance_to(spring144.recoil_position)<.00001,'Recoil spring is invariant at 30 and 144 FPS')
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(false);g.showcase=true
 for f in g.fighters:f.set_physics_process(false);f.set_process(false)
 var p=g.player;p.position=Vector3(0,.01,-15);p.pitch=0;p.yaw=PI;p.cooldown=0;p.ammo[0]=30
 # Fixed input for a two-second automatic burst, exercised via the actual physics loop.
 p.set_physics_process(true);Input.action_press('fire')
 for tick in range(120):await physics_frame
 Input.action_release('fire');p.set_physics_process(false)
 var shots=30-p.ammo[0]
 expect(shots>=21 and shots<=23,'AR cadence keeps fractional tick remainder: '+str(shots)+' shots / 2s')
 var peak=p.pitch;p.shot_age=.2
 for tick in range(60):p.recover_recoil(1.0/60)
 expect(p.pitch<peak and p.pitch>0,'Recoil settles partially without erasing controlled climb')
 p.position=Vector3(0,.01,-15);p.velocity=Vector3.ZERO;p.crouched=true
 var ceiling=StaticBody3D.new();g.add_child(ceiling);ceiling.position=Vector3(0,1.52,-15)
 var col=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2,.20,2);col.shape=box;ceiling.add_child(col)
 await physics_frame;await physics_frame
 expect(not p.can_stand(),'Standing is blocked by a low ceiling')
 ceiling.queue_free();await physics_frame;await physics_frame
 expect(p.can_stand(),'Standing resumes after clearing overhead geometry')
 p.crouched=false;p.cooldown=0;p.ammo[0]=30;p.reload_left=0;p.set_physics_process(true)
 Input.action_press('forward');Input.action_press('sprint');await physics_frame;await physics_frame
 expect(p.sprinting,'Sprint enters while running forward')
 Input.action_press('fire');await physics_frame;await physics_frame
 expect(not p.sprinting and p.ammo[0]<30,'Firing cancels sprint and produces a shot')
 Input.action_release('fire');Input.action_release('forward');Input.action_release('sprint');p.set_physics_process(false)
 # A stale but ordered authoritative snapshot must not refill locally predicted rounds.
 g.net_mode='client';p.pending_predictions.assign([{'sequence':2,'weapon':0},{'sequence':3,'weapon':0}])
 var data=[]
 for f in g.fighters:data.append([f.position,f.yaw,f.pitch,f.health,f.dead,f.kills,f.deaths,f.streak,f.ammo.duplicate(),f.reserves.duplicate(),f.weapon_id,f.respawn_time,f.rewards.duplicate(),f.class_id,f.reload_left,f.crouched,0])
 data[0][8]=[29,36,14,12];data[0][16]=1
 g.snapshot(var_to_bytes(data).compress(FileAccess.COMPRESSION_DEFLATE),[0,0],420,[0,0])
 expect(p.ammo[0]==27 and p.pending_predictions.size()==2,'Delayed snapshot preserves two predicted shots')
 data[0][8][0]=28;data[0][16]=2
 g.snapshot(var_to_bytes(data).compress(FileAccess.COMPRESSION_DEFLATE),[0,0],420,[0,0])
 expect(p.ammo[0]==27 and p.pending_predictions.size()==1,'Partial acknowledgement keeps ammunition stable')
 data[0][8][0]=27;data[0][16]=3
 g.snapshot(var_to_bytes(data).compress(FileAccess.COMPRESSION_DEFLATE),[0,0],420,[0,0])
 expect(p.ammo[0]==27 and p.pending_predictions.is_empty(),'Final acknowledgement reconciles without a duplicate shot')
 g.damage_event(6,0,g.fighters[6].eye(),'HEAD')
 expect(g.hit_time>0 and g.head_time>0,'Authoritative network head hit displays the correct hit marker')
 g.net_mode='offline'
 g.scores=[4,4];g.time_left=0;g.end_match()
 var draw_found=false
 for l in g.ui.find_children('*','Label',true,false):
  if 'DRAW' in l.text:draw_found=true
 expect(draw_found,'A tied match is displayed as a draw')
 g.leave_match();g.class_menu();await process_frame
 expect(g.ui.find_children('*','SubViewport',true,false).size()==3,'All three loadouts use actual rendered weapon previews')
 var out=FileAccess.open('res://tests/regression_v3_report.json',FileAccess.WRITE);out.store_string(JSON.stringify({'passed':checks,'failed':failures,'success':failures==0},'  '))
 print('REGRESSION_V3 ',checks,' passed, ',failures,' failed');quit(0 if failures==0 else 1)
