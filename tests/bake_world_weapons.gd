extends SceneTree
# Offline: bake third-person weapons from the first-person sets (needs a GPU for skinning).
# DISPLAY=:99 godot --path . --script tests/bake_world_weapons.gd
# Output: assets/viewmodels/world_<set>.res (ArrayMesh in socket space: grip at origin, muzzle -Z, metres)
func _initialize():call_deferred('run')
var shrunk={}
# Textures the glTF importer generated (embedded, not files) would be saved inline at 2K: a 512 px copy is plenty here.
func small_textures(material: Material) -> Material:
 if not material is BaseMaterial3D:return material
 var m: BaseMaterial3D=material.duplicate()
 for prop in ['albedo_texture','normal_texture','roughness_texture','metallic_texture','emission_texture','ao_texture']:
  var t: Texture2D=m.get(prop)
  if not t or not '::' in t.resource_path and t.resource_path!='':continue
  if not shrunk.has(t):
   var img=t.get_image();img.decompress();img.resize(mini(img.get_width(),512),mini(img.get_height(),512),Image.INTERPOLATE_LANCZOS);img.generate_mipmaps()
   shrunk[t]=ImageTexture.create_from_image(img)
  m.set(prop,shrunk[t])
 return m
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
   FPSetRig.strip_strays(mi)
   var baked: ArrayMesh=mi.bake_mesh_from_current_skeleton_pose()
   var xf=socket*W.affine_inverse()*mi.global_transform
   # Bounds of the vertices triangles still use (strip_strays leaves unused ones in the arrays).
   var box=AABB();var first=true
   for s in baked.get_surface_count():
    var a=baked.surface_get_arrays(s);var vs: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
    for i in a[Mesh.ARRAY_INDEX]:
     var p=xf*vs[i]
     if first:box=AABB(p,Vector3.ZERO);first=false
     else:box=box.expand(p)
   if box.get_center().length()>1.5 or box.size.length()>3.0:print(' skip parked part ',mi.name);continue
   for s in baked.get_surface_count():
    var st=SurfaceTool.new();st.append_from(baked,s,xf);st.deindex();st.index() # keeps only vertices triangles use
    var material=small_textures(mi.get_active_material(s))
    st.set_material(material);st.commit(out)
  var path='res://assets/viewmodels/world_'+cfg.set+'.res'
  ResourceSaver.save(out,path,ResourceSaver.FLAG_COMPRESS)
  var muzzle=socket*cfg.muzzle
  print('BAKED ',cfg.set,' surfaces ',out.get_surface_count(),' aabb ',out.get_aabb(),' muzzle ',muzzle)
  var meta=ConfigFile.new();meta.set_value('weapon','muzzle',muzzle);meta.save('res://assets/viewmodels/world_'+cfg.set+'.cfg')
  scene.queue_free();await process_frame
 quit()
