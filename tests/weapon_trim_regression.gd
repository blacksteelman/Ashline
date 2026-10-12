extends SceneTree
# The sniper set ships a blue gun-oil can on the barrel in front of the receiver
# (source-scene dressing, not a weapon part). FPSetRig.strip_foreign_part removes it
# by texture colour plus position. This suite guards the removal and its blast radius.
var checks=0
var failures=0
func expect(ok: bool, label: String):
 checks+=1
 print('PASS ' if ok else 'FAIL ',label)
 if not ok:failures+=1
func _initialize():call_deferred('run')

# Islands of a surface with their bounds: blue_share is the share of island vertices
# whose own base-colour texel is clearly blue, which is the rule FPSetRig applies.
func blue_islands(mesh: ArrayMesh, surface: int, threshold: float) -> Array:
 var arrays=mesh.surface_get_arrays(surface)
 var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var idx: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var count=verts.size()
 var parent=PackedInt32Array();parent.resize(count)
 for v in count:parent[v]=v
 var find=func(x):
  var r=x
  while parent[r]!=r:r=parent[r]
  while parent[x]!=r:
   var next=parent[x];parent[x]=r;x=next
  return r
 var tri=idx.size()/3 if idx.size()>0 else count/3
 for t in tri:
  var a=idx[t*3] if idx.size()>0 else t*3
  var b=idx[t*3+1] if idx.size()>0 else t*3+1
  var c=idx[t*3+2] if idx.size()>0 else t*3+2
  var ra=find.call(a);var rb=find.call(b)
  if ra!=rb:parent[rb]=ra
  var rc=find.call(c);ra=find.call(a)
  if ra!=rc:parent[rc]=ra
 var groups={}
 for v in count:
  var r=find.call(v)
  if not groups.has(r):groups[r]=[]
  groups[r].append(v)
 var material=mesh.surface_get_material(surface)
 if not material is BaseMaterial3D or not (material as BaseMaterial3D).albedo_texture:return []
 var image: Image=(material as BaseMaterial3D).albedo_texture.get_image()
 var width=image.get_width();var height=image.get_height()
 var out=[]
 for r in groups:
  var members:Array=groups[r]
  if members.size()<3:continue
  var blue=0.0
  for v in members:
   var texel=image.get_pixel(clampi(int(fposmod(uv[v].x,1.0)*(width-1)),0,width-1),clampi(int((1.0-fposmod(uv[v].y,1.0))*(height-1)),0,height-1))
   if texel.b-(texel.r+texel.g)*.5>threshold:blue+=1.0
  blue/=members.size()
  if blue<FPSetRig.CAN_BLUE_SHARE:continue
  var aabb=AABB(verts[members[0]],Vector3.ZERO)
  for v in members:aabb=aabb.expand(verts[v])
  out.append({'blue':blue,'verts':members.size(),'centre':aabb.get_center(),'size':aabb.size})
 return out

func triangles(mesh: ArrayMesh) -> int:
 var total=0
 for s in mesh.get_surface_count():total+=mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size()/3
 return total

func run():
 # The rule itself: the can's own island must be found on the unmodified mesh.
 var fresh=load(FPSetRig.path(2)).instantiate();root.add_child(fresh)
 var found=0
 var before=0
 var behind_before=0
 for mi in fresh.find_children('*','MeshInstance3D',true,false):
  if not mi.mesh:continue
  before+=triangles(mi.mesh)
  for s in mi.mesh.get_surface_count():
   var material=mi.mesh.surface_get_material(s)
   if not material or material.resource_name!=FPSetRig.CAN_RGB:continue
   var arrays=mi.mesh.surface_get_arrays(s)
   var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   for i in arrays[Mesh.ARRAY_INDEX]:
    if verts[i].z<FPSetRig.CAN_FORWARD:behind_before+=1
   for island in blue_islands(mi.mesh,s,FPSetRig.CAN_BLUE_TEXEL):
    if island.centre.z>FPSetRig.CAN_FORWARD:found+=1
 expect(found>0,'Sniper set really carries blue geometry forward of the receiver')
 expect(behind_before>0,'The unmodified set has geometry behind the receiver to protect (%d indices)'%behind_before)
 fresh.queue_free();await process_frame

 var gun=load(FPSetRig.path(2)).instantiate();root.add_child(gun)
 var rig=FPSetRig.new();rig.bind(gun,2)
 var after=0
 var leftovers=0
 var slender=0
 var surfaces=0
 var armed=false
 for mi in gun.find_children('*','MeshInstance3D',true,false):
  if not mi.mesh:continue
  armed=true
  after+=triangles(mi.mesh)
  for s in mi.mesh.get_surface_count():
   surfaces+=1
   var material=mi.mesh.surface_get_material(s)
   if not material:continue
   if material.resource_name==FPSetRig.CAN_RGB:
    var arrays=mi.mesh.surface_get_arrays(s)
    var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var idx: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    # Islands: the can is compact, the barrel and sling are long and slender.
    var parent=PackedInt32Array();parent.resize(verts.size())
    for v in verts.size():parent[v]=v
    var find=func(x):
     var r=x
     while parent[r]!=r:r=parent[r]
     while parent[x]!=r:
      var next=parent[x];parent[x]=r;x=next
     return r
    for t in range(0,idx.size(),3):
     var a=idx[t];var b=idx[t+1];var c=idx[t+2]
     var ra=find.call(a);var rb=find.call(b)
     if ra!=rb:parent[rb]=ra
     var rc=find.call(c);ra=find.call(a)
     if ra!=rc:parent[rc]=ra
    var groups={}
    for v in verts.size():
     var r=find.call(v)
     if not groups.has(r):groups[r]=[]
     groups[r].append(v)
    for r in groups:
     var members:Array=groups[r]
     if members.size()<50:continue
     var box=AABB(verts[members[0]],Vector3.ZERO)
     for v in members:box=box.expand(verts[v])
     var length=maxf(box.size.x,maxf(box.size.y,box.size.z))
     var cross=minf(box.size.x,minf(box.size.y,box.size.z))
     if length>0.5 and cross<0.05:slender+=1
    for island in blue_islands(mi.mesh,s,FPSetRig.CAN_BLUE_TEXEL):
     if island.centre.z>FPSetRig.CAN_FORWARD:leftovers+=1
 expect(armed and surfaces>0,'Sniper set still builds its meshes')
 expect(after<before,'Blue can triangles are removed from the sniper set (%d -> %d)'%[before,after])
 expect(before-after>400,'Removal matches the size of the can, not a stray triangle (%d triangles)'%(before-after))
 expect(leftovers==0,'No blue-labelled island is left forward of the receiver')
 expect(slender>0,'Barrel and sling keep their long slender islands after removal (%d found)'%slender)
 # Nothing behind the receiver may lose vertices: the buttstock and the sling live there
 # and both sample the can's label inside their UV shells.
 var behind_after=0
 for mi in gun.find_children('*','MeshInstance3D',true,false):
  if not mi.mesh:continue
  for s in mi.mesh.get_surface_count():
   var material=mi.mesh.surface_get_material(s)
   if not material or material.resource_name!=FPSetRig.CAN_RGB:continue
   var arrays=mi.mesh.surface_get_arrays(s)
   var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   for i in arrays[Mesh.ARRAY_INDEX]:
    if verts[i].z<FPSetRig.CAN_FORWARD:behind_after+=1
 expect(behind_after==behind_before and behind_after>0,'Geometry behind the receiver is untouched (%d -> %d indices)'%[behind_before,behind_after])
 gun.queue_free();await process_frame

 # Other weapons must not be touched by the sniper rule - and the colour rule itself
 # must not match anything on them, not merely be skipped by the set-name guard.
 for kind in [0,1,3,4]:
  var other=load(FPSetRig.path(kind)).instantiate();root.add_child(other)
  var before_other=0
  var mask_matches=0
  for mi in other.find_children('*','MeshInstance3D',true,false):
   if not mi.mesh:continue
   before_other+=triangles(mi.mesh)
   for s in mi.mesh.get_surface_count():
    var material=mi.mesh.surface_get_material(s)
    if material and material.resource_name!=FPSetRig.CAN_RGB:continue
    mask_matches+=FPSetRig.can_mask(mi.mesh,s).count(1)
  for mi in other.find_children('*','MeshInstance3D',true,false):FPSetRig.strip_foreign_part(mi,Arsenal.WEAPONS[kind].fp.set)
  var after_other=0
  for mi in other.find_children('*','MeshInstance3D',true,false):
   if mi.mesh:after_other+=triangles(mi.mesh)
  expect(mask_matches==0,'The can rule selects no vertex on weapon %d'%kind)
  expect(before_other==after_other,'Weapon %d is untouched by the foreign-part rule (%d triangles)'%[kind,before_other])
  other.queue_free();await process_frame

 # The third-person bake pipeline must strip the same part.
 var world='res://assets/viewmodels/world_fp_sniper.res'
 expect(ResourceLoader.exists(world),'Third-person sniper bake exists')
 if ResourceLoader.exists(world):
  var baked: ArrayMesh=load(world)
  var expected=baked.get_meta('source_triangle_count',-1)
  expect(expected>0 and triangles(baked)==expected,'Third-person bake kept every triangle it reported (%s)'%str(expected))
  # A handful of barrel vertices sample the can's label inside the shared atlas; the
  # can body itself is thousands of vertices, so the bake must not carry that mass.
  var blue_verts=0
  for s in baked.get_surface_count():
   var material=baked.surface_get_material(s)
   if not material is BaseMaterial3D or not (material as BaseMaterial3D).albedo_texture:continue
   var arrays=baked.surface_get_arrays(s)
   var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
   var image: Image=(material as BaseMaterial3D).albedo_texture.get_image()
   for v in uv.size():
    var texel=image.get_pixel(clampi(int(fposmod(uv[v].x,1.0)*(image.get_width()-1)),0,image.get_width()-1),clampi(int((1.0-fposmod(uv[v].y,1.0))*(image.get_height()-1)),0,image.get_height()-1))
    if texel.b-(texel.r+texel.g)*.5>0.15:blue_verts+=1
  expect(blue_verts<200,'Third-person sniper carries no blue can mass, only atlas bleed (%d vertices)'%blue_verts)
 print('WEAPON_TRIM ',checks,' checks, ',failures,' failures')
 quit(0 if failures==0 else 1)
