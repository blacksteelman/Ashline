extends SceneTree
class AudioTestGame extends 'res://scripts/game.gd':
 func audio_enabled() -> bool:return true
var checks=0
var failures=0
func expect(ok: bool, label: String):
 checks+=1
 print('PASS ' if ok else 'FAIL ',label)
 if not ok:failures+=1
func _initialize():call_deferred('run')
func run():
 var g=AudioTestGame.new();root.add_child(g)
 g.set_process(false);g.set_physics_process(false)
 await physics_frame;await physics_frame
 expect(AudioServer.get_bus_send(AudioServer.get_bus_index('Interior'))=='Master','Original indoor routing')
 expect(AudioServer.get_bus_index('WorldInterior')<0,'No added spatial indoor bus')
 expect(AudioServer.get_bus_effect(AudioServer.get_bus_index('Weapons'),0) is AudioEffectCompressor,'Original weapon compressor')
 expect(AudioServer.get_bus_effect(AudioServer.get_bus_index('Interior'),0) is AudioEffectReverb,'Original room reverb')
 var outside=Vector3(0,50,0)
 for key in Arsenal.WEAPON_SOUNDS:
  var own=g.sound(key,outside,true,-6)
  expect(own is AudioStreamPlayer and own.stream==g.sound_cache[key],key+' original local recording')
  expect(own.bus=='Weapons' and own.volume_db==-6,key+' local bus and gain')
  expect(own.pitch_scale>=.975 and own.pitch_scale<=1.025,key+' original pitch range')
  var remote=g.sound(key,outside,false,-9)
  expect(remote is AudioStreamPlayer3D and remote.stream==g.sound_cache[key+'_far'],key+' original distant recording')
  expect(remote.bus=='World' and remote.global_position==outside,key+' spatial routing')
  expect(remote.max_distance==220 and remote.unit_size==14,key+' original attenuation')
  g.local_shots.clear();own.queue_free();remote.queue_free()
 var roof=StaticBody3D.new();g.add_child(roof);roof.position=outside+Vector3.UP*3
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2,.2,2);shape.shape=box;roof.add_child(shape)
 await physics_frame;await physics_frame
 for local in [true,false]:
  var voice=g.sound('acr',outside,local,-8)
  expect(voice.bus=='Interior','Original indoor playback routing local='+str(local))
  g.local_shots.clear();voice.queue_free()
 roof.queue_free();await physics_frame;await physics_frame
 var oldest=g.sound('acr',outside,true,-8)
 for i in range(3):g.sound('acr',outside,true,-8)
 expect(g.local_shots.size()==3,'Burst keeps three local tails')
 await create_timer(.16).timeout
 expect(not is_instance_valid(oldest),'Oldest burst tail fades and frees')
 g.queue_free();g=null;await process_frame;await process_frame
 await create_timer(.2).timeout # Let the audio thread release the queued playback voices.
 print('AUDIO_DISTANCE ',checks,' checks, ',failures,' failures')
 quit(0 if failures==0 else 1)
