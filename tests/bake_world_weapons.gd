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
# Classify by the source skin binding, not material or a spatial cut: the AK
# shares one material between receiver and magazine, including their hidden faces.
func magazine_vertices(mi: MeshInstance3D, arrays: Array) -> PackedByteArray:
 var count=arrays[Mesh.ARRAY_VERTEX].size()
 var mask=PackedByteArray();mask.resize(count)
 if not mi.skin:return mask
 var sk=mi.get_node(mi.skeleton) as Skeleton3D
 var binds={};var pattern=RegEx.new();pattern.compile('^(Pmag|Mag)_[0-9]+$')
 for i in mi.skin.get_bind_count():
  var name=String(mi.skin.get_bind_name(i))
  if name=='' and mi.skin.get_bind_bone(i)>=0:name=sk.get_bone_name(mi.skin.get_bind_bone(i))
  if pattern.search(name):binds[i]=true
 var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
 var stride=bones.size()/maxi(1,count)
 for v in count:
  var weight=0.0
  for k in stride:
   if binds.has(bones[v*stride+k]):weight+=weights[v*stride+k]
  if weight>.5:mask[v]=1
 return mask

func run():
 var selected=[]
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--weapons='):
   for value in arg.substr(10).split(','):selected.append(int(value))
 for kind in range(Arsenal.WEAPONS.size()):
  if not selected.is_empty() and kind not in selected:continue
  var w=Arsenal.WEAPONS[kind]
  if not w.has('fp'):continue
  var cfg=w.fp
  var scene=load('res://assets/viewmodels/'+cfg.set+'/scene.gltf').instantiate();root.add_child(scene)
  var sk: Skeleton3D=scene.find_child('Skeleton3D',true,false);var ap: AnimationPlayer=scene.find_child('AnimationPlayer',true,false)
  ap.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  for a in ap.get_animation_list():
   if 'Idle' in String(a):ap.play(a);ap.seek(0,true);break
  for i in 4:await process_frame
  ap.pause()
  var wb=-1;var hand=-1;var hand_l=-1
  for i in sk.get_bone_count():
   var n=sk.get_bone_name(i)
   if wb<0 and n.begins_with(cfg.bone) and not '_end' in n:wb=i
   if n.begins_with('Hand_R') and not '_end' in n:hand=i
   if n.begins_with('Hand_L') and not '_end' in n:hand_l=i
  var W=sk.global_transform*sk.get_bone_global_pose(wb)*cfg.frame
  var wrist=W.affine_inverse()*(sk.global_transform*sk.get_bone_global_pose(hand).origin)
  # Socket origin: top of the pistol grip on the barrel centre line (wrist + ~7 cm up, 4 cm forward).
  var grip=Vector3(cfg.muzzle.x,wrist.y+.07/cfg.scale,wrist.z+.04/cfg.scale)
  # The barrel frames (Arsenal fp.frame) are left-handed: flip x back, or the gun comes out mirrored and inside-out.
  var socket=Transform3D(Basis(Vector3.UP,PI).scaled(Vector3.ONE*cfg.scale)*Basis.from_scale(Vector3(-1,1,1)),Vector3.ZERO)*Transform3D(Basis.IDENTITY,-grip)
  var out=ArrayMesh.new();var magazine_surfaces=PackedInt32Array();var triangle_count=0
  for mi in scene.find_children('*','MeshInstance3D',true,false):
   var mat=mi.mesh.surface_get_material(0)
   if mi.name=='Icosphere' or (mat and mat.resource_name=='arms'):continue
   # First-person reload rigs park a second magazine near the weapon in Idle.
   # It is not part of the assembled third-person weapon.
   if (cfg.set=='fp_ak74m' and mi.name=='Object_99') or (cfg.set=='fp_smg' and mi.name=='Object_96'):continue
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
    var arrays=baked.surface_get_arrays(s)
    var mask=magazine_vertices(mi,mi.mesh.surface_get_arrays(s))
    assert(mask.size()==arrays[Mesh.ARRAY_VERTEX].size(),'Skin bake changed vertex order/count')
    var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    if indices.is_empty():
     for v in mask.size():indices.append(v)
    var groups=[PackedInt32Array(),PackedInt32Array()]
    for i in range(0,indices.size(),3):
     var votes=int(mask[indices[i]])+int(mask[indices[i+1]])+int(mask[indices[i+2]])
     assert(votes==0 or votes==3,'Triangle straddles magazine and receiver bindings')
     groups[1 if votes==3 else 0].append_array(indices.slice(i,i+3))
    triangle_count+=indices.size()/3
    var material=small_textures(mi.get_active_material(s))
    for group in 2:
     if groups[group].is_empty():continue
     var part_arrays=arrays.duplicate();part_arrays[Mesh.ARRAY_INDEX]=groups[group]
     # Skin baking may leave float custom channels used by the importer.
     # The world weapon is static; keep geometry/UV/normals, discard skin data.
     for channel in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:part_arrays[channel]=null
     var part=ArrayMesh.new();part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part_arrays)
     if part.get_surface_count()!=1:push_error('Could not create weapon part');quit(1);return
     var st=SurfaceTool.new();st.append_from(part,0,xf);st.deindex();st.index()
     st.set_material(material)
     if group==1:magazine_surfaces.append(out.get_surface_count())
     st.commit(out)
  var baked_triangles=0
  for surface in out.get_surface_count():baked_triangles+=out.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()/3
  if baked_triangles!=triangle_count:push_error('Weapon split lost triangles');quit(1);return
  var path='res://assets/viewmodels/world_'+cfg.set+'.res'
  out.set_meta('magazine_surfaces',magazine_surfaces)
  out.set_meta('source_triangle_count',triangle_count)
  ResourceSaver.save(out,path,ResourceSaver.FLAG_COMPRESS)
  print('MAGAZINE_SURFACES ',kind,' ',magazine_surfaces,' source triangles ',triangle_count)
  var muzzle=socket*cfg.muzzle
  print('BAKED ',cfg.set,' surfaces ',out.get_surface_count(),' aabb ',out.get_aabb(),' muzzle ',muzzle)
  # Where the first-person hands hold this gun (wrists, socket space): soldiers' arm IK uses them (GripIK).
  var to_socket=socket*W.affine_inverse()*sk.global_transform
  var grip_wrist=to_socket*sk.get_bone_global_pose(hand).origin;var support=to_socket*sk.get_bone_global_pose(hand_l).origin
  print('  grip ',grip_wrist,' support ',support)
  var meta=ConfigFile.new();meta.load('res://assets/viewmodels/world_'+cfg.set+'.cfg');meta.set_value('weapon','muzzle',muzzle);meta.set_value('weapon','grip',grip_wrist);meta.set_value('weapon','support',support);meta.save('res://assets/viewmodels/world_'+cfg.set+'.cfg')
  scene.queue_free();await process_frame
 quit()
