extends SceneTree
# A live bot match observed from a few street positions (third-person soldiers in the map).
var directory=ProjectSettings.globalize_path('res://build/screenshots-v8')
func _initialize():call_deferred('run')
func frames(n):
 for i in range(n):await process_frame
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(true)
 await frames(240)
 g.hud.visible=false;g.menu_camera.current=true;g.menu_camera.fov=60
 var shots=0
 for k in range(40):
  await frames(20)
  # Follow the fight: frame the two closest enemies.
  var best=null;var bd=INF
  for a in g.fighters:
   for b in g.fighters:
    if a.team==b.team or a.dead or b.dead:continue
    var d=a.global_position.distance_to(b.global_position)
    if d<bd and d>4:bd=d;best=[a,b]
  if best==null:continue
  var mid=(best[0].global_position+best[1].global_position)*.5
  var side=(best[1].global_position-best[0].global_position).normalized().cross(Vector3.UP)
  g.menu_camera.global_position=best[0].global_position-(best[1].global_position-best[0].global_position).normalized()*3.5+side*1.2+Vector3(0,1.7,0)
  g.menu_camera.look_at(mid+Vector3(0,1.2,0))
  await frames(3);await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(directory+'/battle_%d.png' % shots);print('SHOT ',shots);shots+=1
  if shots>=4:break
 quit()
