extends SceneTree
func _initialize():call_deferred('run')
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(false);g.showcase=true
 g.player.position=Vector3(0,.1,-15);g.player.yaw=PI-.10
 await create_timer(1).timeout
 for f in g.fighters:f.set_physics_process(false)
 var samples=[];var draws=[];var previous=Time.get_ticks_usec()
 for i in range(80):
  await process_frame
  var now=Time.get_ticks_usec();samples.append((now-previous)/1000.0);previous=now
  draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 samples.sort();draws.sort()
 print('PERFORMANCE ',JSON.stringify({'renderer':RenderingServer.get_video_adapter_name(),'resolution':root.size,'median_ms':samples[40],'p95_ms':samples[76],'draw_calls_median':draws[40],'objects':Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}));quit()
