extends SceneTree
# Real, frozen match views. Capture before and after with identical eye positions.
func _initialize():call_deferred('run')
func run():
 var tag='after'
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--tag='):tag=arg.substr(6)
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(false)
 for f in g.fighters:f.set_physics_process(false)
 var views=[[Vector3(-15,.18,-18),Vector3(-22,1.3,-24)],
  [Vector3(-18,3.15,15.8),Vector3(-23,4.35,20.6)],
  [Vector3(22,.18,28),Vector3(22,1.2,32.2)],
  [Vector3(-21,.18,-18),Vector3(-23,1.3,-25.0)],
  [Vector3(-22,3.15,18.3),Vector3(-17.2,4.0,14.8)]]
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path('res://build/interior-captures'))
 for i in views.size():
  var p=g.player;p.global_position=views[i][0];p.rotation.y=0
  var d=views[i][1]-(p.position+Vector3.UP*1.62)
  p.yaw=atan2(-d.x,-d.z);p.pitch=atan2(d.y,Vector2(d.x,d.z).length())
  for frame in range(10):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://build/interior-captures/%s-%d.png'%[tag,i]));print('INTERIOR_SHOT ',i)
 quit()
