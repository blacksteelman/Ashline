extends SceneTree
var checks=0
var failures=0
func expect(ok: bool, label: String):
 checks+=1
 print('PASS ' if ok else 'FAIL ',label)
 if not ok:failures+=1
func _initialize():call_deferred('run')
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g)
 await process_frame
 expect(AudioServer.get_bus_send(AudioServer.get_bus_index('Interior'))=='Weapons','Indoor local fire keeps weapon compression')
 expect(AudioServer.get_bus_send(AudioServer.get_bus_index('WorldInterior'))=='World','Indoor enemy fire remains on the spatial world channel')
 expect(AudioServer.get_bus_effect( AudioServer.get_bus_index('Weapons'),0) is AudioEffectCompressor,'Weapon bus retains its compressor')
 for distance in [0.0,10.0,20.0,30.0,40.0,50.0,100.0]:
  var layers=AudioMix.world_layers(distance)
  var power=0.0
  for layer in layers:power+=pow(db_to_linear(layer.gain_db),2)
  expect(absf(power-1.0)<.00001,'Gunshot transition preserves layer power at %dm'%distance)
 expect(AudioMix.world_layers(3.0).size()==1 and AudioMix.world_layers(3.0)[0].suffix=='_near','Close enemy shot uses the close recording')
 expect(AudioMix.world_layers(80.0).size()==1 and AudioMix.world_layers(80.0)[0].suffix=='_far','Distant enemy shot uses the far recording')
 var previous=1.0;var continuous=true
 for distance in range(0,101):
  var amplitude=0.0
  for layer in AudioMix.world_layers(distance):
   if layer.suffix=='_near':amplitude=db_to_linear(layer.gain_db)
  if amplitude>previous+.000001 or absf(amplitude-previous)>.05:continuous=false
  previous=amplitude
 expect(continuous,'Close shot layer fades monotonically without an abrupt distance switch')
 for key in Arsenal.WEAPON_SOUNDS:
  var near=g.sound_cache[key+'_near'] as AudioStreamWAV
  var far=g.sound_cache[key+'_far'] as AudioStreamWAV
  expect(near!=null and not near.stereo and near.mix_rate==48000,key+' close positional recording is mono 48kHz')
  expect(far!=null and not far.stereo,key+' far positional recording remains mono')
  var voice=g.play_sound_voice(key+'_near',Vector3(0,1,0),false,-6.0,.99,'World',true)
  expect(voice is AudioStreamPlayer3D and voice.stream==near and voice.max_distance==220 and is_equal_approx(voice.pitch_scale,.99),key+' creates the actual positional playback voice')
  voice.queue_free()
 g.menu_camera.global_position=Vector3(0,1,30)
 var mixed=g.play_world_shot('acr',Vector3(0,1,0),-3.0,1.01,'World')
 expect(mixed.size()==2 and mixed[0].stream==g.sound_cache.acr_near and mixed[1].stream==g.sound_cache.acr_far,'Actual listener distance selects both recordings in the transition')
 expect(mixed.size()==2 and is_equal_approx(mixed[0].pitch_scale,mixed[1].pitch_scale),'Both layers share the same shot pitch')
 for voice in mixed:voice.queue_free()
 var roof=StaticBody3D.new();g.add_child(roof);roof.position=Vector3(0,3,0)
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2,.2,2);shape.shape=box;roof.add_child(shape)
 await physics_frame;await physics_frame
 expect(AudioMix.bus(g,'acr',Vector3(0,1,0),true)=='Interior','Roof ray routes local fire through indoor weapon effects')
 expect(AudioMix.bus(g,'acr',Vector3(0,1,0),false)=='WorldInterior','Roof ray routes enemy fire through indoor spatial effects')
 roof.queue_free();await physics_frame;await physics_frame
 expect(AudioMix.bus(g,'acr',Vector3(0,1,0),true)=='Weapons','Open street restores the local weapon bus')
 expect(AudioMix.bus(g,'acr',Vector3(0,1,0),false)=='World','Open street restores the spatial world bus')
 g.queue_free();await process_frame
 print('AUDIO_DISTANCE ',checks,' checks, ',failures,' failures')
 quit(0 if failures==0 else 1)
