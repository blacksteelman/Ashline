class_name DistrictDetail
extends RefCounted
static func build(arena: Node3D):
 var trim=Art.mat('concrete',Color('#9b9d8d'))
 var steel=Art.mat('metal',Color('#777d73'),.3)
 var soot=Art.mat('soot',Color('#252b28'))
 var paint=Art.mat('paint',Color('#858775'))
 var grime=StandardMaterial3D.new();grime.albedo_texture=load('res://assets/wall_grime.png');grime.albedo_color=Color(1,1,1,.48);grime.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;grime.cull_mode=BaseMaterial3D.CULL_DISABLED;grime.roughness=1;grime.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
 for x in [-10,10]:
  for z in [-17,17]:
   # Concrete bands, doorway lintels and drain gutters give each facade a construction logic.
   for side in [-1,1]:
    for dz in [-6.5,6.5]:
     var edge=x+side*5.78
     Art.box(arena,Vector3(edge,.22,z+dz),Vector3(.10,.42,5.0),trim)
     Art.box(arena,Vector3(edge,3.86,z+dz),Vector3(.15,.16,5.1),trim)
     var stain=MeshInstance3D.new();stain.mesh=QuadMesh.new();stain.mesh.size=Vector2(5,1.65);stain.material_override=grime;arena.add_child(stain);stain.position=Vector3(edge+side*.012,.82,z+dz);stain.rotation.y=PI/2
     Art.box(arena,Vector3(edge,4.80,z+dz),Vector3(.12,.13,5.1),steel)
    Art.box(arena,Vector3(x+side*5.76,3.47,z),Vector3(.18,.18,7.9),steel)
    for dx in [-3.6,3.6]:
     Art.box(arena,Vector3(x+dx,.22,z+side*9.28),Vector3(3.8,.42,.10),trim)
     Art.box(arena,Vector3(x+dx,3.65,z+side*9.28),Vector3(3.8,.17,.14),trim)
    Art.box(arena,Vector3(x,3.47,z+side*9.28),Vector3(3.5,.18,.15),steel)
    for dx in [-1.72,1.72]:Art.box(arena,Vector3(x+dx,1.70,z+side*9.3),Vector3(.09,3.4,.09),steel)
   # Recessed window reveals, mullions and uneven remaining panes.
   for side in [-1,1]:
    for dz in [-6.5,6.5]:
     var edge=x+side*5.84
     Art.box(arena,Vector3(edge,2.27,z+dz),Vector3(.54,.14,2.94),trim)
     for offset in [-1.36,1.36]:Art.box(arena,Vector3(edge,3,z+dz+offset),Vector3(.16,1.7,.07),steel)
     Art.box(arena,Vector3(edge,3.81,z+dz),Vector3(.16,.08,2.8),steel)
     Art.box(arena,Vector3(edge,3,z+dz),Vector3(.15,1.6,.06),steel)
     for pane in [-1,1]:
      if (int(x+z+dz)+pane)%3==0:continue
      var glass=Art.mat('glass'+str(pane),Color(.22,.29,.28,.35),.08);glass.roughness=.22;glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
      Art.box(arena,Vector3(edge+side*.015,3.02,z+dz+pane*.68),Vector3(.02,1.54,1.25),glass)
   # Low maintenance kerbs outline the yard without changing the existing routes.
   for side in [-1,1]:Art.box(arena,Vector3(x+side*5.97,.055,z),Vector3(.25,.11,18),trim)
   # Painted sector plate on the entrance, readable as a landmark instead of floating text.
   Art.box(arena,Vector3(x,3.15,z-9.32),Vector3(3.1,.65,.07),soot)
   for dx in [-1.45,1.45]:
    for dy in [-.23,.23]:Art.sphere(arena,Vector3(x+dx,3.15+dy,z-9.365),Vector3(.035,.035,.012),steel)
 # Cargo reinforcing corners and roof ribs replace flat rectangular silhouettes.
 for x in [-23,23]:
  for z in [-16,4,18]:
   for side in [-1,1]:
    for end in [-1,1]:Art.box(arena,Vector3(x+side*1.77,1.25,z+end*2.5),Vector3(.14,2.56,.14),steel)
    for i in range(11):Art.box(arena,Vector3(x+side*1.78,1.25,z-2.25+i*.45),Vector3(.06,2.32,.09),steel)
    Art.box(arena,Vector3(x+side*.86,1.25,z-2.53),Vector3(1.65,2.35,.055),paint)
    Art.box(arena,Vector3(x+side*.62,1.25,z-2.58),Vector3(.035,2.13,.045),steel)
   for i in range(9):Art.box(arena,Vector3(x,2.52,z-2+i*.5),Vector3(3.4,.07,.075),steel)
 # Road drainage grates: shallow grooves, not additional navigation obstacles.
 for z in [-24,-5,7,25]:
  for x in [-3.8,3.8]:
   Art.box(arena,Vector3(x,.016,z),Vector3(.48,.015,1.1),soot)
   for i in range(9):Art.box(arena,Vector3(x,.026,z-.47+i*.115),Vector3(.44,.018,.027),steel)
 # Overhead utility cables on the existing lamp posts.
 for x in [-28,28]:
  for start in [-26,0]:
   for segment in range(16):
    var t=(segment+.5)/16.0;var cable=Art.cylinder(arena,Vector3(x,6.65-sin(t*PI)*.62,start+t*26),.012,26.0/16,soot)
    cable.rotation.x=PI/2+cos(t*PI)*.075
