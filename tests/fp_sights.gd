extends SceneTree
# Sight-line profile per first-person set: barrel axis by PCA of the main weapon mesh, profile of
# the top centre line along it, and optic tube centres. Coordinates in the weapon bone frame.
func _initialize():call_deferred('run')
func pca_axis(pts: PackedVector3Array) -> Vector3:
 var c=Vector3.ZERO
 for p in pts:c+=p
 c/=pts.size()
 var cov=[[0.0,0.0,0.0],[0.0,0.0,0.0],[0.0,0.0,0.0]]
 for p in pts:
  var d=p-c
  for i in 3:
   for j in 3:cov[i][j]+=d[i]*d[j]
 var v=Vector3(1,1,1).normalized()
 for k in 50:
  v=Vector3(cov[0][0]*v.x+cov[0][1]*v.y+cov[0][2]*v.z,cov[1][0]*v.x+cov[1][1]*v.y+cov[1][2]*v.z,cov[2][0]*v.x+cov[2][1]*v.y+cov[2][2]*v.z).normalized()
 return v
func run():
 var keys=['fp_acr','fp_ak74m','fp_smg','fp_sniper','fp_pistol']
 for a in OS.get_cmdline_user_args():
  if a.begins_with('--key='):keys=[a.substr(6)]
 for key in keys:
  var vm=load('res://assets/viewmodels/'+key+'/scene.gltf').instantiate();root.add_child(vm)
  var sk: Skeleton3D=vm.find_child('Skeleton3D',true,false);var ap: AnimationPlayer=vm.find_child('AnimationPlayer',true,false)
  for n in ap.get_animation_list():
   if 'Idle' in n:ap.play(n);ap.seek(0,true)
  await process_frame;await process_frame
  var wb=-1;var cam=-1
  for i in sk.get_bone_count():
   var n=sk.get_bone_name(i)
   if n.begins_with('Head_Cam') and not '_end' in n:cam=i
   if wb<0 and not n.begins_with('Bone') and not n.begins_with('Arm') and not n.begins_with('UpArm') and not n.begins_with('Forearm') and not n.begins_with('Hand') and not n.begins_with('IK') and not n.begins_with('Head') and not n.begins_with('_root') and not n.begins_with('Root') and not '_end' in n:wb=i
  var bone_t=sk.global_transform*sk.get_bone_global_pose(wb)
  var cam_t=sk.global_transform*sk.get_bone_global_pose(cam);cam_t.basis=cam_t.basis.orthonormalized()
  var meshes={}
  for mi in vm.find_children('*','MeshInstance3D',true,false):
   var mat=mi.mesh.surface_get_material(0)
   if mi.name=='Icosphere' or (mat and mat.resource_name=='arms'):continue
   var baked: ArrayMesh=mi.bake_mesh_from_current_skeleton_pose()
   var pts=PackedVector3Array()
   for s in baked.get_surface_count():
    for v in baked.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:pts.append(mi.global_transform*v)
   meshes[mi.name+':'+(mat.resource_name if mat else '')]=pts
  var main=''
  for k in meshes:
   if main=='' or meshes[k].size()>meshes[main].size():main=k
  var body=meshes[main]
  var axis=pca_axis(body)
  # Camera bone axis closest to the barrel is the view direction; the most upward of the rest is up.
  var cand=[]
  for i in 3:
   cand.append(cam_t.basis[i]);cand.append(-cam_t.basis[i])
  var labels=['+x','-x','+y','-y','+z','-z']
  var fi=0
  for i in 6:
   if absf(cand[i].dot(axis))>absf(cand[fi].dot(axis)) or (absf(cand[i].dot(axis))==absf(cand[fi].dot(axis)) and cand[i].dot(axis)>0):fi=i
  if cand[fi].dot(axis)<0:fi=fi^1
  var cam_fwd=cand[fi]
  # Muzzle is the end of the barrel away from the camera.
  var bc=Vector3.ZERO
  for p in body:bc+=p
  bc/=body.size()
  if (bc-cam_t.origin).dot(cam_fwd)<0:fi=fi^1;cam_fwd=cand[fi]
  if axis.dot(cam_fwd)<0:axis=-axis
  var ui=-1
  for i in 6:
   if i/2==fi/2:continue
   # 'up': arms hang below the view, so up points away from the hand.
   if ui<0 or cand[i].y>cand[ui].y:ui=i
  var up=(cand[ui]-axis*cand[ui].dot(axis)).normalized()
  print('VIEW fwd ',labels[fi],' up ',labels[ui])
  var right=axis.cross(up).normalized()
  # Weapon frame W: origin at the camera, x right, y up, z = barrel axis (world units).
  var W=Transform3D(Basis(right,up,axis),cam_t.origin)
  var all=PackedVector3Array()
  for k in meshes:all.append_array(meshes[k])
  var local=Array(all).map(func(p):return W.affine_inverse()*p)
  var bl=Array(body).map(func(p):return W.affine_inverse()*p)
  var zs=bl.map(func(v):return v.z);zs.sort()
  var xs=bl.map(func(v):return v.x);xs.sort()
  var xmid=xs[xs.size()/2];var z0=zs[int(zs.size()*.01)];var z1=zs[int(zs.size()*.99)]
  print('KEY ',key,' main ',main,' len ',z1-z0,' xmid ',xmid,' barrel-vs-camfwd ',rad_to_deg(axis.angle_to(cam_fwd)))
  print('CAMBASIS ',cam_t.basis)
  print('W_IN_BONE ',bone_t.affine_inverse()*W)
  for k in meshes:
   var ml=Array(meshes[k]).map(func(p):return W.affine_inverse()*p)
   var mz=ml.map(func(v):return v.z);mz.sort()
   print(' MESH ',k,' z ',snappedf(mz[int(mz.size()*.02)],.001),'..',snappedf(mz[int(mz.size()*.98)],.001))
   # Cross-section centres near both ends (optic tubes).
   for q in [.08,.92]:
    var zc=mz[int(mz.size()*q)];var c=Vector3.ZERO;var n=0
    for v in ml:
     if absf(v.z-zc)<.01:c+=v;n+=1
    if n>0:print('  SECTION q',q,' centre ',c/n,' n=',n)
  var z=z0
  while z<z1:
   var top=-INF;var cnt=0
   for v in local:
    if v.z>=z and v.z<z+.015 and absf(v.x-xmid)<.006:top=maxf(top,v.y);cnt+=1
   if cnt>0:print('Z %.3f top %.4f n=%d' % [z,top,cnt])
   z+=.015
  vm.queue_free()
 quit()
