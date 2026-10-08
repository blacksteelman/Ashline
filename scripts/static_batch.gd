class_name StaticBatch
extends RefCounted
# Spatially bounded batches preserve useful frustum/shadow culling. Collision stays independent.
static func bake(root: Node3D):
 var batches={}
 for node in root.find_children('*','MeshInstance3D',true,false):
  var visual=node as MeshInstance3D
  if not visual.mesh or not visual.is_visible_in_tree():continue
  var transform=root.global_transform.affine_inverse()*visual.global_transform
  var cell=Vector2i(floori(transform.origin.x/16),floori(transform.origin.z/16))
  for surface in range(visual.mesh.get_surface_count()):
   var material=visual.get_active_material(surface)
   if not material or (material is BaseMaterial3D and material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED):continue
   var key=str(cell)+'/'+str(material.get_instance_id())
   if not batches.has(key):
    var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_material(material)
    batches[key]={'tool':tool,'visuals':[]}
   # Normalize indexing before appending: mixed indexed primitives and
   # unindexed ruined walls otherwise silently lose their faces.
   var source=SurfaceTool.new();source.create_from(visual.mesh,surface);source.index()
   batches[key].tool.append_from(source.commit(),0,transform)
   batches[key].visuals.append(visual)
 for key in batches:
  var batch=batches[key]
  var combined=MeshInstance3D.new();combined.name='StaticBatch';combined.mesh=batch.tool.commit();root.add_child(combined)
  for visual in batch.visuals:
   if is_instance_valid(visual) and not visual.is_queued_for_deletion():visual.queue_free()
