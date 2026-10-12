extends SceneTree
# Guard the viewmodel-only fill: never turn it into a light on actors or scenery.
var failures=0
var checks=0
func expect(ok: bool, label: String):
 checks+=1
 print('PASS ' if ok else 'FAIL ',label)
 if not ok:failures+=1
func _initialize():call_deferred('run')
func run():
 var camera=Camera3D.new();root.add_child(camera)
 var fill=ViewmodelMaterial.add_fill(camera)
 expect(fill.get_parent()==camera,'Bounce follows local camera')
 expect(fill.light_cull_mask==ViewmodelMaterial.FILL_LAYER,'Bounce affects only reserved viewmodel layer')
 var world_mesh=MeshInstance3D.new();world_mesh.mesh=BoxMesh.new();root.add_child(world_mesh)
 expect((world_mesh.layers & fill.light_cull_mask)==0,'Default world geometry receives no bounce')
 expect(not fill.shadow_enabled,'Bounce adds no shadow map')
 expect(fill.light_bake_mode==Light3D.BAKE_DISABLED,'Bounce cannot leak through SDFGI into the world')
 expect(fill.light_energy>0 and fill.light_energy<2.2,'Bounce remains weaker than the key light')
 for kind in Arsenal.WEAPONS.size():
  var gun=load(FPSetRig.path(kind)).instantiate();root.add_child(gun)
  ViewmodelMaterial.apply(gun)
  var count=0;var isolated=true;var sun=true
  for mesh in gun.find_children('*','MeshInstance3D',true,false):
   if not mesh.mesh:continue
   count+=1
   isolated=isolated and (mesh.layers & fill.light_cull_mask)!=0
   sun=sun and (mesh.layers & 1)!=0
  expect(count>0 and isolated,'Weapon %d and arms receive bounce'%kind)
  expect(sun,'Weapon %d retains world sun and ambient lighting'%kind)
  gun.queue_free();await process_frame
 world_mesh.queue_free();camera.queue_free();await process_frame
 print('VIEWMODEL_LIGHTING ',checks,' checks, ',failures,' failures')
 quit(0 if failures==0 else 1)
