extends SceneTree
var failures=0
var count=0
func _initialize():call_deferred('run')
func check(ok: bool,message: String):
 count+=1;print(('PASS: ' if ok else 'FAIL: ')+message)
 if not ok:failures+=1
func run():
 var game=load('res://main.tscn').instantiate();root.add_child(game)
 await physics_frame;await physics_frame
 game.showcase=true;game.start_match(false)
 var p=game.player;var gun=p.gun
 var arms=gun.find_child('ViewmodelArms',true,false)
 check(arms!=null and arms.visible,'AR viewmodel contains visible deforming arm mesh')
 var skeleton=gun.find_child('Skeleton3D',true,false)
 check(skeleton!=null and skeleton.get_bone_count()>=40,'Licensed arm skeleton retains finger deformation')
 check(arms.extra_cull_margin>=.6,'Viewmodel bounds retain posed arms during hip fire')
 check(gun.get_meta('deforming_arms',false),'AR uses the deforming arm presentation path')
 check(p.view.magazine!=null and p.view.bolt!=null,'Reload magazine and bolt remain independently articulated')
 var clip=p.view.contact_clip
 check(clip!=&'' and p.view.animator.get_animation(clip).length>=1.9,'Authored two-second arm reload survives import')
 var index=skeleton.find_bone('hand.L')
 p.view.animator.seek(0,true);skeleton.force_update_all_bone_transforms()
 var ready=skeleton.get_bone_global_pose(index).origin
 p.view.animator.seek(1,true);skeleton.force_update_all_bone_transforms()
 var removed=skeleton.get_bone_global_pose(index).origin
 check(ready.distance_to(removed)>.10,'Reload moves the actual deforming support wrist to the removed magazine')
 p.view.animator.seek(2,true);skeleton.force_update_all_bone_transforms()
 check(skeleton.get_bone_global_pose(index).origin.distance_to(ready)<.002,'Reload returns support hand to its ready contact')
 var world=Art.weapon(game,0,false)
 check(not world.find_child('ViewmodelArms',true,false).visible,'World rifles hide first-person arms')
 var surface_normal=false
 for mesh in gun.find_children('*','MeshInstance3D',true,false):
  for i in range(mesh.mesh.get_surface_count()):
   var m=mesh.get_active_material(i)
   if m is StandardMaterial3D and m.normal_enabled and m.normal_texture!=null:surface_normal=true
 check(surface_normal,'Imported weapon retains PBR normal maps')
 var props=load('res://assets/district_props.glb').instantiate()
 check(props.get_child_count()==6,'Industrial runtime library includes six selected equipment meshes')
 props.free()
 var query=PhysicsRayQueryParameters3D.create(Vector3(-14.6,1,-12),Vector3(-14.6,1,-16),1)
 check(not game.arena.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),'Service equipment has physical bullet cover')
 var path=game.arena.route(Vector3(-10,.1,-24),Vector3(-10,.1,-10))
 check(not path.is_empty(),'Workshop equipment leaves its central route navigable')
 # Evaluate real imported skin matrices, not just bone positions: the old
 # asset left unweighted forearm triangles far from either posed hand.
 p.view.animator.seek(0,true);skeleton.force_update_all_bone_transforms()
 var points_near_hands=true
 var left=skeleton.get_bone_global_pose(skeleton.find_bone('hand.L')).origin
 var right=skeleton.get_bone_global_pose(skeleton.find_bone('hand.R')).origin
 for surface in range(arms.mesh.get_surface_count()):
  var arrays=arms.mesh.surface_get_arrays(surface)
  var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
  for vertex in range(vertices.size()):
   var posed=Vector3.ZERO;var total=0.0
   for influence in range(4):
    var weight=weights[vertex*4+influence]
    if weight<.00001:continue
    var bind=bones[vertex*4+influence]
    var bone=skeleton.find_bone(arms.skin.get_bind_name(bind))
    if bone<0:bone=arms.skin.get_bind_bone(bind)
    posed+=(skeleton.get_bone_global_pose(bone)*arms.skin.get_bind_pose(bind)*vertices[vertex])*weight
    total+=weight
   var distance=minf(posed.distance_to(left),posed.distance_to(right))
   if total<.9 or distance>.25:points_near_hands=false
 check(points_near_hands,'Imported hand vertices stay weighted and close to the posed wrists')
 var report={'checks':count,'failures':failures}
 var f=FileAccess.open('res://tests/art_v7_report.json',FileAccess.WRITE);f.store_string(JSON.stringify(report,'  '));f.close()
 print('ART_V7 ',JSON.stringify(report));quit(1 if failures else 0)
