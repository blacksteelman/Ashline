class_name Frontend
extends RefCounted
const INK=Color('#10181b')
const PAPER=Color('#e2e2d7')
const MUTED=Color('#899a9d')
const ACCENT=Color('#a9c9bd')
static func backdrop(g: Node, heavy: bool=false):
 var shade=ColorRect.new();shade.size=Vector2(1600,900);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var shader=Shader.new();shader.code='shader_type canvas_item; uniform float strength=0.9; void fragment(){float a=mix(strength,0.13,smoothstep(0.1,0.94,UV.x));COLOR=vec4(0.022,0.035,0.043,a);}'
 var material=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter('strength',.96 if heavy else .90);shade.material=material;g.ui.add_child(shade)
 var line=ColorRect.new();line.position=Vector2(72,80);line.size=Vector2(38,3);line.color=ACCENT;g.ui.add_child(line)
 var brand=g.label(g.ui,'ASHLINE  /  FIELD OPERATIONS',14,ACCENT);brand.position=Vector2(126,69)
 var footer=g.label(g.ui,'FOUNDRY DISTRICT     /     6 v 6     /     TEAM DEATHMATCH',12,MUTED);footer.position=Vector2(72,848)
 var version=g.label(g.ui,'ALPHA 0.3',12,MUTED);version.position=Vector2(1410,848)
static func column(g: Node, pos: Vector2, width: float) -> VBoxContainer:
 var v=VBoxContainer.new();g.ui.add_child(v);v.position=pos;v.custom_minimum_size.x=width;v.add_theme_constant_override('separation',14);return v
static func space(v: Node, height: float):
 var c=Control.new();c.custom_minimum_size.y=height;v.add_child(c)
static func main(g: Node):
 backdrop(g)
 var v=column(g,Vector2(72,170),470)
 g.label(v,'ASHLINE',88,PAPER)
 g.label(v,'A district fractured. A line to hold.',20,MUTED)
 space(v,35)
 g.button(v,'01     PLAY',g.class_menu)
 g.button(v,'02     LOCAL NETWORK',func():network(g))
 g.button(v,'03     SETTINGS',func():g.settings_menu(false))
 g.button(v,'04     EXIT TO DESKTOP',func():g.get_tree().quit())
 space(v,25)
 g.label(v,'ONE MAP. TWO TEAMS. NO DOWNTIME.',12,ACCENT)
 var info=column(g,Vector2(1160,654),330)
 g.label(info,'04 / FOUNDRY',24,PAPER)
 g.label(info,'Industrial quarter\nDawn · clear visibility',15,MUTED)
static func network(g: Node):
 g.clear_ui();backdrop(g,true)
 var v=column(g,Vector2(72,167),540);g.label(v,'LOCAL NETWORK',42,PAPER);g.label(v,'Host a match or join a server by IP address.',16,MUTED);space(v,18)
 var classes=OptionButton.new()
 for item in Arsenal.CLASSES:classes.add_item(item.name)
 classes.selected=g.selected_class;classes.item_selected.connect(func(i):g.selected_class=i);v.add_child(classes)
 g.button(v,'HOST  /  6 v 6 WITH BOT FILL',func():g.start_host(false))
 space(v,16)
 g.label(v,'SERVER ADDRESS',12,ACCENT);g.address_field=LineEdit.new();g.address_field.placeholder_text='127.0.0.1';g.address_field.custom_minimum_size.y=40;v.add_child(g.address_field)
 g.button(v,'CONNECT',func():g.start_client(g.address_field.text))
 g.label(v,'UDP 27841 · bots yield their slots to players',13,MUTED);space(v,20);g.button(v,'BACK',g.main_menu)
static func classes(g: Node, respawn: bool=false):
 g.clear_ui();backdrop(g,true)
 var heading=g.label(g.ui,'NEXT DEPLOYMENT' if respawn else 'CHOOSE YOUR LOADOUT',38,PAPER);heading.position=Vector2(72,140)
 var detail=g.label(g.ui,'Your next life begins with this kit.' if respawn else '75 eliminations  /  7 minutes  /  fast respawn',16,MUTED);detail.position=Vector2(72,197)
 for i in range(3):
  var card=PanelContainer.new();g.ui.add_child(card);card.position=Vector2(72+i*485,258);card.custom_minimum_size=Vector2(455,500)
  var style=StyleBoxFlat.new();style.bg_color=Color(.042,.060,.065,.91);style.border_width_top=2;style.border_color=ACCENT if i==g.selected_class else Color('#38484a');style.content_margin_left=24;style.content_margin_right=24;style.content_margin_top=20;style.content_margin_bottom=24;card.add_theme_stylebox_override('panel',style)
  var v=VBoxContainer.new();v.add_theme_constant_override('separation',11);card.add_child(v)
  g.label(v,'0'+str(i+1)+' / '+Arsenal.CLASSES[i].name,24,PAPER)
  preview(v,i)
  g.label(v,Arsenal.WEAPONS[i].name,18,PAPER)
  g.label(v,['Versatile at close and medium range.','Fast handling. Built for tight routes.','Deliberate shots. Strong at distance.'][i],14,MUTED)
  space(v,4);g.label(v,'P-12 SIDEARM  /  2 × FRAG',13,MUTED)
  g.label(v,Arsenal.CLASSES[i].perk,14,ACCENT)
  g.label(v,['Reload 22% faster','Sprint 12% faster','Explosive damage reduced by 25%'][i],14,MUTED)
  space(v,8)
  var c=i
  g.button(v,'EQUIP FOR NEXT LIFE' if respawn else 'DEPLOY',func():
   if respawn:g.queue_class(c);g.resume()
   else:g.selected_class=c;g.start_match(false))
 var back=column(g,Vector2(72,782),260);g.button(back,'BACK',g.pause_menu if respawn else g.main_menu)
static func preview(parent: Node, kind: int):
 var container=SubViewportContainer.new();container.custom_minimum_size=Vector2(400,145);container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(container)
 var viewport=SubViewport.new();viewport.size=Vector2i(400,145);viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;container.add_child(viewport)
 var world=Node3D.new();viewport.add_child(world);var gun=Art.weapon(world,kind,false);gun.rotation.z=-.08
 var camera=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.43;camera.position=Vector3(1,.45,.15);camera.look_at(Vector3(0,0,-.23));camera.current=true
 var env=WorldEnvironment.new();var settings=Environment.new();settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color('#c6d7d9');settings.ambient_light_energy=.95;env.environment=settings;world.add_child(env)
 var key=DirectionalLight3D.new();world.add_child(key);key.rotation_degrees=Vector3(-35,-45,-10);key.light_color=Color('#ffdfaf');key.light_energy=1.4
