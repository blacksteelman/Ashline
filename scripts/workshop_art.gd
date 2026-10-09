class_name WorkshopArt
extends RefCounted
static func prop(arena: Node3D,name: String,pos: Vector3,scale_value: float=1.0,angle: float=0.0) -> Node3D:
 var library=load('res://assets/district_props.glb').instantiate()
 arena.add_child(library)
 for child in library.get_children():
  if child.name!=name:library.remove_child(child);child.queue_free()
 library.name='Workshop_'+name;library.position=pos;library.scale=Vector3.ONE*scale_value;library.rotation.y=angle
 return library
static func build(arena: Arena):
 # West service bay: authored placement, clear circulation and matching cover.
 prop(arena,'control_terminal_mat',Vector3(-14.6,.10,-14.5),.30,-PI/2)
 arena.block(Vector3(-14.6,1.05,-14.5),Vector3(.95,1.9,.90),Art.mat('metal'),'metal',false).visible=false
 prop(arena,'tank_control_panel_mat',Vector3(-14.65,.10,-20),.50,-PI/2)
 arena.block(Vector3(-14.65,.95,-20),Vector3(.60,1.7,1.4),Art.mat('metal'),'metal',false).visible=false
 prop(arena,'pipe_05',Vector3(-10,3.8,-19),.90)
 prop(arena,'pipe_07',Vector3(-10,3.65,-13),1.0)
 prop(arena,'vent_mat',Vector3(-13,3.2,-26.25),.80)
 prop(arena,'vent_mat',Vector3(-15.1,3.25,-21.5),.65,-PI/2)
 # A recognizable plant silhouette behind this section, outside the playable lanes.
 prop(arena,'smokestack_mat',Vector3(-25,0,-43),.85,.15)
 prop(arena,'smokestack_mat',Vector3(-34,0,-39),.70,-.1)
 var dark=Art.mat('workshop_sign',Color('#26342f'))
 Art.box(arena,Vector3(-10,3.14,-26.36),Vector3(3.1,.65,.045),dark)
 # Flush skirting and roof trusses tie equipment into the building structure.
 var steel=Art.mat('metal',Color('#777c70'),.35)
 for z in [-22,-17,-12]:
  Art.box(arena,Vector3(-10,4.65,z),Vector3(10.6,.10,.10),steel)
  for side in [-1,1]:
   var brace=Art.box(arena,Vector3(-10+side*2.6,4.25,z),Vector3(5.3,.065,.065),steel);brace.rotation.z=side*.16
 for x in [-14.95,-5.05]:Art.box(arena,Vector3(x,.30,-17),Vector3(.065,.40,17.2),Art.mat('soot',Color('#383e36')))

 # The north roof remains intact around a narrow skylight; sunlight now has an
 # actual ceiling to occlude it rather than washing every interior surface.
 Art.box(arena,Vector3(-10,5.05,-22),Vector3(11,.22,8),Art.mat('concrete'))
 var lamp_material=StandardMaterial3D.new();lamp_material.albedo_color=Color('#e4dbc2')
 lamp_material.emission_enabled=true;lamp_material.emission=Color('#ffd0a0');lamp_material.emission_energy_multiplier=2.0
 for z in [-23.0,-11.0]:
  Art.box(arena,Vector3(-10,4.78,z),Vector3(2.2,.12,.24),Art.mat('charcoal',Color('#20282b')))
  Art.box(arena,Vector3(-10,4.69,z),Vector3(1.9,.025,.14),lamp_material)
  var light=SpotLight3D.new();arena.add_child(light);light.position=Vector3(-10,4.60,z)
  light.rotation.x=-PI/2;light.light_color=Color('#ffdcac');light.light_energy=2.2
  light.spot_range=7.0;light.spot_angle=65;light.shadow_enabled=true
 # Steel cabinet backs stay tight to the equipment rather than floating across
 # the wall openings. Their extents fit inside the existing physical cover.
 var ochre=Art.mat('workshop_paint',Color('#9b723b'))
 for z in [-14.5,-20.0]:
  Art.box(arena,Vector3(-14.98,1.1,z),Vector3(.045,1.7,.85),Art.mat('metal',Color('#465351'),.25))
  Art.box(arena,Vector3(-14.94,1.92,z),Vector3(.06,.045,.85),ochre)
 # Small storage objects occupy the wall edge, leaving the middle lane open.
 for i in range(3):
  var barrel=Art.cylinder(arena,Vector3(-13.6+i*.78,.55,-24.8),.31,.9,Art.mat('metal',Color('#6b6150'),.3))
  for h in [.18,.82]:Art.cylinder(arena,Vector3(barrel.position.x,h,-24.8),.32,.045,steel)
 Art.text(arena,Vector3(-14.7,2.7,-25.68),'ISOLATE POWER\nBEFORE SERVICE',18,Color('#d8ba7d'))
