extends SceneTree
func _initialize():call_deferred('run')
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g);await process_frame
 var count={}
 for m in g.arena.find_children('*','MeshInstance3D',true,false):
  var mat=m.get_active_material(0)
  if mat and mat is StandardMaterial3D:
   var key=str(mat.albedo_texture.resource_path if mat.albedo_texture else mat.albedo_color)+' cull='+str(mat.cull_mode)
   count[key]=count.get(key,0)+1
 print(count);quit()
