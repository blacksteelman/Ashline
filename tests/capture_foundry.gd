extends SceneTree
# Actual match captures of the stair and its ground passage. Run with:
# godot --path . --script tests/capture_foundry.gd -- --graphics=1
func _initialize():call_deferred('run')
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(false)
 for f in g.fighters:f.set_physics_process(false)
 var views=[[Vector3(27,.2,13.8),Vector3(31.5,1.8,16)], [Vector3(31,3.2,21),Vector3(31,.5,14)], [Vector3(29,.18,18),Vector3(32,1.8,18)]]
 for i in views.size():
  var p=g.player;p.global_position=views[i][0];p.rotation.y=0
  var d=views[i][1]-(p.position+Vector3.UP*1.62)
  p.yaw=atan2(-d.x,-d.z);p.pitch=atan2(d.y,Vector2(d.x,d.z).length())
  for frame in range(10):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://build/verification/foundry-stair-'+str(i)+'.png'));print('STAIR_SHOT ',i)
 quit()
