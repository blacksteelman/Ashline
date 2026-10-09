extends SceneTree
# Offline: bake third-person weapons from the first-person sets (needs a GPU for skinning).
# DISPLAY=:99 godot --path . --script tests/bake_world_weapons.gd
# Output: assets/viewmodels/world_<set>.res (ArrayMesh in socket space: grip at origin, muzzle -Z, metres)
func _initialize():call_deferred('run')
func run():
 for kind in range(Arsenal.WEAPONS.size()):
  var w=Arsenal.WEAPONS[kind]
  if not w.has('fp'):continue
  var cfg=w.fp
  var scene=load('res://assets/viewmodels/'+cfg.set+'/scene.gltf').instantiate();root.add_child(scene)
  var sk: Skeleton3D=scene.find_child('Skeleton3D',true,false);var ap: AnimationPlayer=scene.find_child('AnimationPlayer',true,false)
  for a in ap.get_animation_list():
   if 'Idle' in String(a):ap.play(a);ap.seek(0,true);break
  for i in 4:await process_frame
  ap.pause()
  var wb=-1;var hand=-1
  for i in sk.get_bone_count():
   var n=sk.get_bone_name(i)
   if wb<0 and n.begins_with(cfg.bone) and not '_end' in n:wb=i
   if n.begins_with('Hand_R') and not '_end' in n:hand=i
  var W=sk.global_transform*sk.get_bone_global_pose(wb)*cfg.frame
  var wrist=W.affine_inverse()*(sk.global_transform*sk.get_bone_global_pose(hand).origin)
  # Socket origin: top of the pistol grip on the barrel centre line (wrist + ~7 cm up, 4 cm forward).
  var grip=Vector3(cfg.muzzle.x,wrist.y+.07/cfg.scale,wrist.z+.04/cfg.scale)
  var socket=Transform3D(Basis(Vector3.UP,PI).scaled(Vector3.ONE*cfg.scale),Vector3.ZERO)*Transform3D(Basis.IDENTITY,-grip)
  var out=ArrayMesh.new()
  for mi in scene.find_children('*','MeshInstance3D',true,false):
   var mat=mi.mesh.surface_get_material(0)
   if mi.name=='Icosphere' or (mat and mat.resource_name=='arms'):continue
   var baked: ArrayMesh=mi.bake_mesh_from_current_skeleton_pose()
   var xf=socket*W.affine_inverse()*mi.global_transform
   var box=xf*baked.get_aabb()
   if box.get_center().length()>1.5 or box.size.length()>3.0:print(' skip parked part ',mi.name);continue
   for s in baked.get_surface_count():
    var st=SurfaceTool.new();st.append_from(baked,s,xf)
    var material=mi.get_active_material(s)
    st.set_material(material);st.commit(out)
  var path='res://assets/viewmodels/world_'+cfg.set+'.res'
  ResourceSaver.save(out,path,ResourceSaver.FLAG_COMPRESS)
  var muzzle=socket*cfg.muzzle
  print('BAKED ',cfg.set,' surfaces ',out.get_surface_count(),' aabb ',out.get_aabb(),' muzzle ',muzzle)
  var meta=ConfigFile.new();meta.set_value('weapon','muzzle',muzzle);meta.save('res://assets/viewmodels/world_'+cfg.set+'.cfg')
  scene.queue_free();await process_frame
 quit()
