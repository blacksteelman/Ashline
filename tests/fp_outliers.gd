extends SceneTree
func _initialize():call_deferred('run')
func run():
 for key in ['fp_acr','fp_ak74m','fp_smg','fp_sniper','fp_pistol']:
  var vm=load('res://assets/viewmodels/'+key+'/scene.gltf').instantiate();root.add_child(vm)
  var sk: Skeleton3D=vm.find_child('Skeleton3D',true,false);var ap: AnimationPlayer=vm.find_child('AnimationPlayer',true,false)
  for a in ap.get_animation_list():
   if 'Idle' in String(a):ap.play(a);ap.seek(0,true)
  for i in 3:await process_frame
  var cam=-1
  for i in sk.get_bone_count():
   if sk.get_bone_name(i).begins_with('Head_Cam') and not '_end' in sk.get_bone_name(i):cam=i
  var c=(sk.global_transform*sk.get_bone_global_pose(cam)).origin
  for mi in vm.find_children('*','MeshInstance3D',true,false):
   if mi.name=='Icosphere':continue
   var baked: ArrayMesh=mi.bake_mesh_from_current_skeleton_pose()
   var orig: ArrayMesh=mi.mesh
   var skin: Skin=mi.skin
   var dists=[];var far={}
   for s in baked.get_surface_count():
    var v=baked.surface_get_arrays(s)[Mesh.ARRAY_VERTEX];var oa=orig.surface_get_arrays(s);var bones=oa[Mesh.ARRAY_BONES];var weights=oa[Mesh.ARRAY_WEIGHTS]
    var per=bones.size()/v.size()
    for i in v.size():
     var d=(mi.global_transform*v[i]).distance_to(c)
     dists.append(d)
     if d>2.5:
      var bi=bones[i*per];var bn=skin.get_bind_name(bi) if skin and skin.get_bind_name(bi)!=&'' else str(bi)
      if skin and skin.get_bind_bone(bi)>=0:bn=sk.get_bone_name(skin.get_bind_bone(bi))
      far[bn]=far.get(bn,0)+1
   dists.sort()
   print(key,' ',mi.name,' n=',dists.size(),' median ',snappedf(dists[dists.size()/2],.01),' p99 ',snappedf(dists[int(dists.size()*.99)],.01),' max ',snappedf(dists[-1],.01),' far ',far)
  vm.queue_free();await process_frame
 quit()
