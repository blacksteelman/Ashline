extends SceneTree
# Exports the first-person arms' triangles (UVs + glove/sleeve by dominant bone) for tools/paint_fp_arms.py.
# godot --headless --path . --script tests/export_arms_uv.gd  ->  build/arms_uv.json
func _initialize():
 var scene=load('res://assets/viewmodels/fp_acr/scene.gltf').instantiate();root.add_child(scene)
 var sk: Skeleton3D=scene.find_child('Skeleton3D',true,false)
 var tris=[]
 for mi in scene.find_children('*','MeshInstance3D',true,false):
  var mesh: ArrayMesh=mi.mesh
  for s in mesh.get_surface_count():
   var mat=mesh.surface_get_material(s)
   if not mat or mat.resource_name!='arms':continue
   var names=[]
   for b in mi.skin.get_bind_count():
    var n=String(mi.skin.get_bind_name(b))
    if n=='' and mi.skin.get_bind_bone(b)>=0:n=sk.get_bone_name(mi.skin.get_bind_bone(b))
    names.append(n)
   var a=mesh.surface_get_arrays(s);var uv: PackedVector2Array=a[Mesh.ARRAY_TEX_UV];var bones=a[Mesh.ARRAY_BONES];var weights=a[Mesh.ARRAY_WEIGHTS];var idx=a[Mesh.ARRAY_INDEX]
   var per=bones.size()/uv.size()
   for t in range(0,idx.size(),3):
    var glove=0.0;var total=0.0
    for c in 3:
     var v=idx[t+c]
     for k in per:
      var w=weights[v*per+k];total+=w
      var n: String=names[bones[v*per+k]]
      if n.begins_with('Hand_') or n.begins_with('Bone_L.') or n.begins_with('Bone_R.'):glove+=w
    tris.append([[uv[idx[t]].x,uv[idx[t]].y],[uv[idx[t+1]].x,uv[idx[t+1]].y],[uv[idx[t+2]].x,uv[idx[t+2]].y],glove/maxf(total,1e-6)])
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path('res://build'))
 var f=FileAccess.open('res://build/arms_uv.json',FileAccess.WRITE);f.store_string(JSON.stringify(tris));f.close()
 print('ARMS_UV ',tris.size())
 quit()
