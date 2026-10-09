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
 var footer=g.label(g.ui,'FOUNDRY DISTRICT     /     6 v 6     /     '+('DOMINATION' if g.settings.get('mode','tdm')=='dom' else 'TEAM DEATHMATCH'),12,MUTED);footer.position=Vector2(72,848)
 var version=g.label(g.ui,'ALPHA 0.8',12,MUTED);version.position=Vector2(1410,848)
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
 for i in range(3):classes.add_item(g.class_loadout(i).name)
 classes.selected=g.selected_class;classes.item_selected.connect(func(i):g.selected_class=i);v.add_child(classes)
 g.button(v,'HOST  /  6 v 6 WITH BOT FILL',func():g.start_host(false))
 space(v,16)
 g.label(v,'SERVER ADDRESS',12,ACCENT);g.address_field=LineEdit.new();g.address_field.placeholder_text='127.0.0.1';g.address_field.custom_minimum_size.y=40;v.add_child(g.address_field)
 g.button(v,'CONNECT',func():g.start_client(g.address_field.text))
 g.label(v,'UDP 27841 · bots yield their slots to players',13,MUTED);space(v,20);g.button(v,'BACK',g.main_menu)
static func classes(g: Node, respawn: bool=false):
 g.clear_ui();backdrop(g,true)
 var heading=g.label(g.ui,'NEXT DEPLOYMENT' if respawn else 'CHOOSE YOUR LOADOUT',38,PAPER);heading.position=Vector2(72,120)
 var detail=g.label(g.ui,'Your next life begins with this kit.' if respawn else g.mode_summary(),16,MUTED);detail.position=Vector2(72,177)
 if not respawn:
  # Game mode toggle.
  var modes=HBoxContainer.new();g.ui.add_child(modes);modes.position=Vector2(1010,128);modes.add_theme_constant_override('separation',10)
  for entry in [['tdm','TEAM DEATHMATCH'],['dom','DOMINATION']]:
   var b=Button.new();b.text=entry[1];b.toggle_mode=true;b.button_pressed=g.settings.get('mode','tdm')==entry[0];b.custom_minimum_size=Vector2(230,44);modes.add_child(b)
   var key=entry[0]
   b.pressed.connect(func():g.settings.mode=key;g.save_settings();classes(g,respawn))
 for i in range(3):
  var loadout: Dictionary=g.class_loadout(i)
  var card=PanelContainer.new();g.ui.add_child(card);card.position=Vector2(72+i*485,228);card.custom_minimum_size=Vector2(455,540)
  var style=StyleBoxFlat.new();style.bg_color=Color(.042,.060,.065,.91);style.border_width_top=2;style.border_color=ACCENT if i==g.selected_class else Color('#38484a');style.content_margin_left=24;style.content_margin_right=24;style.content_margin_top=20;style.content_margin_bottom=24;card.add_theme_stylebox_override('panel',style)
  var v=VBoxContainer.new();v.add_theme_constant_override('separation',9);card.add_child(v)
  g.label(v,'0'+str(i+1)+' / '+loadout.name,24,PAPER)
  preview(v,loadout.primary)
  g.label(v,Arsenal.WEAPONS[loadout.primary].name,18,PAPER)
  g.label(v,Arsenal.WEAPON_NOTES[loadout.primary],14,MUTED)
  g.label(v,'WALTHER P38  /  2 × FRAG',13,MUTED)
  for tier in range(3):
   var perk=Arsenal.PERKS[tier][loadout.perks[tier]]
   g.label(v,'PERK %d  ·  %s' % [tier+1,perk.name],14,ACCENT);g.label(v,perk.text,13,MUTED)
  space(v,4)
  var c=i
  var row=HBoxContainer.new();row.add_theme_constant_override('separation',10);v.add_child(row)
  var go=g.button(row,'EQUIP' if respawn else 'DEPLOY',func():
   if respawn:g.queue_class(c);g.resume()
   else:g.selected_class=c;g.start_match(false))
  go.custom_minimum_size.x=200
  var edit=g.button(row,'EDIT CLASS',func():create_class(g,c,respawn));edit.custom_minimum_size.x=180
 var back=column(g,Vector2(72,792),260);g.button(back,'BACK',g.pause_menu if respawn else g.main_menu)
# CREATE A CLASS: name, primary weapon and one perk per tier, saved to settings.
static func create_class(g: Node, slot: int, respawn: bool):
 g.clear_ui();backdrop(g,true)
 var draft: Dictionary=g.class_loadout(slot).duplicate(true)
 var v=column(g,Vector2(72,120),620)
 g.label(v,'CREATE A CLASS  /  SLOT 0'+str(slot+1),38,PAPER)
 g.label(v,'Pick one primary and one perk from each tier. Secondary: Walther P38, 2 × frag.',15,MUTED);space(v,8)
 g.label(v,'CLASS NAME',12,ACCENT)
 var name_field=LineEdit.new();name_field.text=draft.name;name_field.max_length=16;name_field.custom_minimum_size.y=40;v.add_child(name_field)
 g.label(v,'PRIMARY WEAPON',12,ACCENT)
 var weapon=OptionButton.new();v.add_child(weapon)
 for kind in Arsenal.PRIMARIES:weapon.add_item(Arsenal.WEAPONS[kind].name,kind)
 weapon.selected=Arsenal.PRIMARIES.find(draft.primary)
 var note=g.label(v,Arsenal.WEAPON_NOTES[draft.primary],13,MUTED)
 weapon.item_selected.connect(func(index):draft.primary=Arsenal.PRIMARIES[index];note.text=Arsenal.WEAPON_NOTES[draft.primary])
 for tier in range(3):
  g.label(v,'PERK %d' % (tier+1),12,ACCENT)
  var choice=OptionButton.new();v.add_child(choice)
  for perk in Arsenal.PERKS[tier]:choice.add_item(perk.name)
  choice.selected=draft.perks[tier]
  var text=g.label(v,Arsenal.PERKS[tier][draft.perks[tier]].text,13,MUTED)
  var t=tier
  choice.item_selected.connect(func(index):draft.perks[t]=index;text.text=Arsenal.PERKS[t][index].text)
 space(v,10)
 var row=HBoxContainer.new();row.add_theme_constant_override('separation',12);v.add_child(row)
 g.button(row,'SAVE CLASS',func():
  draft.name=name_field.text;g.save_class(slot,draft)
  if respawn:g.queue_class(slot)
  classes(g,respawn))
 g.button(row,'DEFAULTS',func():g.save_class(slot,Arsenal.CLASSES[slot]);create_class(g,slot,respawn))
 g.button(row,'BACK',func():classes(g,respawn))
static func preview(parent: Node, kind: int):
 var container=SubViewportContainer.new();container.custom_minimum_size=Vector2(400,145);container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(container)
 var viewport=SubViewport.new();viewport.size=Vector2i(400,145);viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;container.add_child(viewport)
 var world=Node3D.new();viewport.add_child(world);var gun=Art.world_weapon(world,kind)
 if not gun:gun=Art.weapon(world,kind,false)
 gun.rotation.z=-.08
 var camera=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.43;camera.position=Vector3(1,.45,.15);camera.look_at(Vector3(0,0,-.23));camera.current=true
 var env=WorldEnvironment.new();var settings=Environment.new();settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color('#c6d7d9');settings.ambient_light_energy=.95;env.environment=settings;world.add_child(env)
 var key=DirectionalLight3D.new();world.add_child(key);key.rotation_degrees=Vector3(-35,-45,-10);key.light_color=Color('#ffdfaf');key.light_energy=1.4
