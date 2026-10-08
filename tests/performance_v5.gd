extends SceneTree
func _initialize():call_deferred('run')
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.showcase=true;g.start_match(false)
 g.player.position=Vector3(0,.1,-15);g.player.yaw=PI-.10
 await create_timer(1).timeout
 for actor in g.fighters:actor.set_physics_process(false)
 var samples=[];var draws=[];var previous=Time.get_ticks_usec()
 for i in range(30):
  await process_frame
  var now=Time.get_ticks_usec();samples.append((now-previous)/1000.0);previous=now
  draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 samples.sort();draws.sort()
 var report={'adapter':RenderingServer.get_video_adapter_name(),'renderer':RenderingServer.get_current_rendering_method(),'resolution':[root.size.x,root.size.y],'sample_frames':30,'median_ms':samples[15],'p95_ms':samples[28],'draw_calls_median':draws[15],'nodes':Performance.get_monitor(Performance.OBJECT_NODE_COUNT),'cpu_threads':OS.get_processor_count(),'cpu_model':OS.get_processor_name(),'graphics_profile':g.settings.graphics,'msaa':root.msaa_3d,'note':'Software llvmpipe rendering. This does not predict performance on a gaming GPU.'}
 var file=FileAccess.open('res://tests/performance_v5_report.json',FileAccess.WRITE);file.store_string(JSON.stringify(report,'  '))
 print('PERFORMANCE_V5 ',JSON.stringify(report));quit()
