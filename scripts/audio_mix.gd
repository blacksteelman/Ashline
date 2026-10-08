class_name AudioMix
extends RefCounted
static func configure():
 if AudioServer.get_bus_index('Weapons')>=0:return
 for name in ['Weapons','World','Interior','Ambience']:
  var index=AudioServer.bus_count;AudioServer.add_bus(index);AudioServer.set_bus_name(index,name);AudioServer.set_bus_send(index,'Master')
 var limiter=AudioEffectHardLimiter.new();limiter.ceiling_db=-.8;limiter.pre_gain_db=0;AudioServer.add_bus_effect(0,limiter)
 var room=AudioEffectReverb.new();room.room_size=.38;room.damping=.72;room.wet=.13;room.dry=1;room.predelay_msec=12;AudioServer.add_bus_effect(AudioServer.get_bus_index('Interior'),room)
 AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Ambience'),-3)
static func bus(game: Node3D, key: String, position: Vector3, local: bool) -> String:
 if key=='ambient':return 'Ambience'
 if key in ['rifle','smg','marksman','pistol']:
  var roof=PhysicsRayQueryParameters3D.create(position,position+Vector3.UP*5,1)
  if not game.get_world_3d().direct_space_state.intersect_ray(roof).is_empty():return 'Interior'
  return 'Weapons' if local else 'World'
 return 'World'
