extends SceneTree
# Same three player views for comparing lighting / map changes: build/screenshots-v8/look_<tag>_<i>.png
# DISPLAY=:99 godot --path . --resolution 1280x720 --script tests/capture_look.gd -- --tag=before [--graphics=2]
func _initialize():call_deferred('run')
func frames(n):
 for i in range(n):await process_frame
func run():
 var tag='look'
 for a in OS.get_cmdline_user_args():
  if a.begins_with('--tag='):tag=a.substr(6)
 var g=load('res://main.tscn').instantiate();root.add_child(g)
 g.start_match(false)
 for f in g.fighters:
  if not f.local_player:f.set_physics_process(false)
 var views=[[Vector3(1.5,.1,-30),PI,-.02],[Vector3(-9,.1,-6),-2.2,-.05],[Vector3(14,.1,16),2.5,-.03]]
 for i in views.size():
  var p=g.player;p.set_physics_process(false);p.global_position=views[i][0];p.yaw=views[i][1];p.pitch=views[i][2];p.rotation.y=0
  # No TAA or auto-exposure accumulation in these fixed balanced-preset views.
  await frames(12);await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://build/screenshots-v8/look_%s_%d.png'%[tag,i]));print('SHOT ',i)
 quit()
