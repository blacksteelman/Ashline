class_name Ruins
extends RefCounted
static func wall(size: Vector3, seed_value: int) -> ArrayMesh:
 var random=RandomNumberGenerator.new();random.seed=seed_value
 var along_x=size.x>size.z
 var width=size.x if along_x else size.z
 var thickness=size.z if along_x else size.x
 var polygon=PackedVector2Array([Vector2(-width/2,-size.y/2),Vector2(width/2,-size.y/2)])
 var segments=maxi(3,ceili(width/.65))
 for i in range(segments+1):
  var x=width/2-width*i/segments
  var damage=random.randf_range(.04,minf(.62,size.y*.45))
  if i%4==0:damage*=.3
  polygon.append(Vector2(x,size.y/2-damage))
 var triangles=Geometry2D.triangulate_polygon(polygon)
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1,1]:
  for index in range(0,triangles.size(),3):
   for j in range(3):
    var point=polygon[triangles[index+j if side==1 else index+2-j]]
    var position=Vector3(point.x,point.y,side*thickness/2)
    var normal=Vector3(0,0,side)
    if not along_x:position=Vector3(position.z,position.y,position.x);normal=Vector3(side,0,0)
    surface.set_normal(normal);surface.set_uv(Vector2(point.x,point.y));surface.add_vertex(position)
 for i in range(polygon.size()):
  var a=polygon[i];var b=polygon[(i+1)%polygon.size()]
  var normal2=Vector2(b.y-a.y,a.x-b.x).normalized()
  var normal=Vector3(normal2.x,normal2.y,0) if along_x else Vector3(0,normal2.y,normal2.x)
  for point in [Vector3(a.x,a.y,-thickness/2),Vector3(b.x,b.y,-thickness/2),Vector3(a.x,a.y,thickness/2),Vector3(a.x,a.y,thickness/2),Vector3(b.x,b.y,-thickness/2),Vector3(b.x,b.y,thickness/2)]:
   if not along_x:point=Vector3(point.z,point.y,point.x)
   surface.set_normal(normal);surface.set_uv(Vector2(point.x+point.z,point.y));surface.add_vertex(point)
 surface.generate_tangents()
 return surface.commit()
