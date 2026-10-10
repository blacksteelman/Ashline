extends Control
# Rotating, player-centred minimap. The backdrop is rasterised once from the real
# collision geometry (top-down rays), so it always matches the map that is loaded.
const SIZE=196.0
const ZOOM=3.2 # pixels per metre on screen
const RES=2.0 # texels per metre in the backdrop
var game: Node3D
var backdrop: ImageTexture
var origin=Vector2.ZERO # world XZ of texel (0,0)
var teal=Color('#73c0c4')
var orange=Color('#dba477')
var ivory=Color('#dedfce')

func _ready():
 clip_contents=true;mouse_filter=Control.MOUSE_FILTER_IGNORE
 position=Vector2(28,28);size=Vector2(SIZE,SIZE)

func _physics_process(_dt):
 if backdrop or not game or not game.arena or not game.arena.is_inside_tree():return
 if Engine.get_physics_frames()<3:return
 rasterise()

func rasterise():
 var bounds: Rect2=game.arena.BOUNDS.grow(4)
 origin=bounds.position
 var w=int(bounds.size.x*RES);var h=int(bounds.size.y*RES)
 var image=Image.create(w,h,false,Image.FORMAT_RGBA8)
 var space=game.arena.get_world_3d().direct_space_state
 var query=PhysicsRayQueryParameters3D.new();query.collision_mask=1|8
 for y in range(h):
  for x in range(w):
   var p=origin+Vector2(x+.5,y+.5)/RES
   query.from=Vector3(p.x,40,p.y);query.to=Vector3(p.x,-2,p.y)
   var hit=space.intersect_ray(query)
   var top=hit.position.y if hit else -1.0
   var c: Color
   if top<-.5:c=Color(0,0,0,0)
   elif top>2.6:c=Color(.36,.43,.42,.92) # buildings and roofs
   elif top>.55:c=Color(.27,.33,.32,.9) # cover, containers, walls
   else:c=Color(.10,.14,.15,.82) # walkable ground
   image.set_pixel(x,y,c)
 # Outline building edges so blocks read at small size.
 var edged=image.duplicate()
 for y in range(1,h-1):
  for x in range(1,w-1):
   var c=image.get_pixel(x,y)
   if c.r>.3 and (image.get_pixel(x+1,y).r<.3 or image.get_pixel(x-1,y).r<.3 or image.get_pixel(x,y+1).r<.3 or image.get_pixel(x,y-1).r<.3):
    edged.set_pixel(x,y,Color(.55,.63,.6,.95))
 backdrop=ImageTexture.create_from_image(edged)

func _process(_dt):
 visible=game and game.state in ['match','results'] and not game.menu_open and game.player!=null and not Input.is_action_pressed('scoreboard')
 if visible:
  scale=get_viewport_rect().size/Vector2(1600,900);queue_redraw()

func to_screen(world: Vector3, p: Node3D) -> Vector2:
 var d=Vector2(world.x-p.position.x,world.z-p.position.z)*ZOOM
 return Vector2(SIZE,SIZE)*.5+d.rotated(p.yaw)

func _draw():
 var p=game.player
 if not p:return
 draw_rect(Rect2(Vector2.ZERO,size),Color(.025,.04,.045,.72))
 if backdrop:
  # Map texel -> screen: translate to player, rotate so the view direction points up.
  var t=Transform2D(p.yaw,Vector2(SIZE,SIZE)*.5)*Transform2D().scaled(Vector2.ONE*ZOOM)*Transform2D(0,origin-Vector2(p.position.x,p.position.z))
  draw_set_transform_matrix(t*Transform2D().scaled(Vector2.ONE/RES))
  draw_texture(backdrop,Vector2.ZERO)
  draw_set_transform_matrix(Transform2D.IDENTITY)
 # Radar information only: teammates always, enemies when recon is up or they fire unsuppressed.
 for f in game.fighters:
  if f.dead or f==p:continue
  var pos=to_screen(f.position,p)
  if f.team==p.team:draw_circle(pos,2.6,teal)
  elif game.radar_time[p.team]>0 or f.last_shot>0:draw_circle(pos,3.2,orange)
 var c=Vector2(SIZE,SIZE)*.5
 draw_colored_polygon(PackedVector2Array([c+Vector2(0,-7),c+Vector2(4.5,5),c+Vector2(0,2.5),c+Vector2(-4.5,5)]),ivory)
 # View cone.
 var fov=deg_to_rad(game.settings.get('fov',80)*.5)
 draw_line(c,c+Vector2(0,-60).rotated(-fov),Color(1,1,1,.12),1);draw_line(c,c+Vector2(0,-60).rotated(fov),Color(1,1,1,.12),1)
 # North marker on the rim.
 var north=Vector2(0,-1).rotated(p.yaw)*(SIZE*.5-9)+c
 draw_string(get_theme_default_font(),north+Vector2(-4,4),'N',HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color('#94abaa'))
 draw_rect(Rect2(Vector2.ZERO,size),Color('#536d70'),false,1)
