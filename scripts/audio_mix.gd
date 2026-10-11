class_name AudioMix
extends RefCounted
static func configure():
 if AudioServer.get_bus_index('Weapons')>=0:return
 for name in ['Weapons','World','Interior','WorldInterior','Ambience']:
  var index=AudioServer.bus_count;AudioServer.add_bus(index);AudioServer.set_bus_name(index,name);AudioServer.set_bus_send(index,'Master')
 var limiter=AudioEffectHardLimiter.new();limiter.ceiling_db=-.8;limiter.pre_gain_db=0;AudioServer.add_bus_effect(0,limiter)
 var punch=AudioEffectCompressor.new();punch.threshold=-14;punch.ratio=4;punch.attack_us=200;punch.release_ms=120;punch.gain=3;AudioServer.add_bus_effect(AudioServer.get_bus_index('Weapons'),punch)
 var room=AudioEffectReverb.new();room.room_size=.38;room.damping=.72;room.wet=.13;room.dry=1;room.predelay_msec=12;AudioServer.add_bus_effect(AudioServer.get_bus_index('Interior'),room)
 AudioServer.set_bus_send(AudioServer.get_bus_index('Interior'),'Weapons')
 AudioServer.set_bus_send(AudioServer.get_bus_index('WorldInterior'),'World')
 AudioServer.add_bus_effect(AudioServer.get_bus_index('WorldInterior'),room.duplicate())
 AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Ambience'),-3)

# Select at the shot's listener distance. Constant-power transition keeps the
# close transient through street fights and blends into the distant recording.
static func world_layers(distance: float) -> Array:
 var blend=smoothstep(10.0,50.0,maxf(0.0,distance))
 var layers=[]
 for pair in [['_near',sqrt(1.0-blend)],['_far',sqrt(blend)]]:
  if pair[1]>.001:layers.append({'suffix':pair[0],'gain_db':linear_to_db(pair[1])})
 return layers
static func bus(game: Node3D, key: String, position: Vector3, local: bool) -> String:
 if key=='ambient':return 'Ambience'
 if key in Arsenal.WEAPON_SOUNDS:
  var roof=PhysicsRayQueryParameters3D.create(position,position+Vector3.UP*5,1)
  if not game.get_world_3d().direct_space_state.intersect_ray(roof).is_empty():return 'Interior' if local else 'WorldInterior'
  return 'Weapons' if local else 'World'
 return 'World'
