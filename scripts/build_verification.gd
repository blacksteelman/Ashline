extends RefCounted
# Runs inside the exported executable; editor-only tests cannot catch missing raw CFGs
# or an asset the exporter skipped, because load()/ConfigFile paths are invisible to it.
# This is what caught the shipped Windows build failing on every impact with
# "No loader found for resource: res://assets/smoke.png".
const FILES=[
 # load() at runtime: a missing import or an exporter filter breaks the build
 'res://assets/smoke.png','res://assets/fx/bullet_hole.png','res://assets/fx/spark.png',
 'res://assets/fx/muzzle_front_0.png','res://assets/fx/muzzle_front_1.png','res://assets/fx/muzzle_front_2.png',
 'res://assets/fx/muzzle_side_0.png','res://assets/fx/muzzle_side_1.png','res://assets/fx/muzzle_side_2.png',
 'res://assets/shaders/surface.gdshader','res://assets/shaders/viewmodel.gdshader',
 'res://assets/shaders/viewmodel_glass.gdshader','res://assets/shaders/viewmodel_fx.gdshader',
 'res://assets/shaders/road_paint.gdshader','res://assets/shaders/facade_weathering.gdshader',
 'res://assets/interface.ttf','res://assets/mono.ttf',
 'res://scripts/bolt_modifier.gd','res://scripts/hud.gd','res://scripts/frontend.gd','res://scripts/domination.gd',
]
const SOUNDS=['ambient','reload','step','hit','kill','explosion','mag_out','mag_in','bolt','impact_metal',
 'impact_concrete','ricochet','step_concrete','step_metal','dryfire','impact_body']
const WEAPON_SOUNDS=['acr','ak','sniper','pistol','smg']
const TEAM_CAMO=['ocp','emr','mm14']

static func run(host: Node3D):
 var failed=false
 # Raw files the scripts read directly: ConfigFile never touches the resource loader.
 for kind in Arsenal.WEAPONS.size():
  var path='res://assets/viewmodels/world_'+Arsenal.WEAPONS[kind].fp.set+'.cfg'
  var cfg=ConfigFile.new()
  var valid=cfg.load(path)==OK
  var weapon=Art.world_weapon(host,kind)
  if not weapon:
   print('EXPORTED_CALIBRATION ',kind,' FAIL missing weapon')
   failed=true
   continue
  for key in ['muzzle','grip','support','grip_fingers','grip_thumb','support_fingers','support_thumb']:
   valid=valid and cfg.has_section_key('weapon',key) and weapon.has_meta(key)
   if valid:valid=weapon.get_meta(key).is_equal_approx(cfg.get_value('weapon',key))
  valid=valid and weapon.find_child('MagazineRig',true,false)!=null
  print('EXPORTED_CALIBRATION ',kind,' ', 'PASS' if valid else 'FAIL',' ',path)
  failed=failed or not valid
  # Art.world_weapon() parents the node under the host itself, so it is already in the
  # tree: just free it again after checking.
  weapon.free()
 # Textures, shaders, fonts and scripts are imported and go through the loader.
 for path in FILES:
  var ok=ResourceLoader.exists(path)
  if ok:
   var res=load(path)
   ok=res!=null
  print('EXPORTED_RESOURCE ', 'PASS' if ok else 'FAIL',' ',path)
  failed=failed or not ok
 # Sounds: the game loads them with load() into its sound cache, so verify exactly that.
 # FileAccess.file_exists() on the .wav would fail in a build even when the imported
 # stream is present, because the importer turns the wav into a .sample resource.
 var sounds={}
 for name in SOUNDS:
  sounds[name]=load('res://assets/'+name+'.wav')
 for name in WEAPON_SOUNDS:
  for suffix in ['','_far']:
   sounds[name+suffix]=load('res://assets/sfx/'+name+suffix+'.wav')
 var silent=[]
 for key in sounds:
  if not (sounds[key] is AudioStream):silent.append(key)
 print('EXPORTED_SOUND ', 'PASS' if silent.is_empty() else 'FAIL',' ',str(sounds.size()),' streams loaded', '' if silent.is_empty() else ('missing: '+str(silent)))
 failed=failed or not silent.is_empty()
 # A loaded stream must also be playable, which is what a silent export would break.
 var player=AudioStreamPlayer.new()
 host.add_child(player)
 player.stream=sounds['ambient']
 if player.stream is AudioStreamWAV:player.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
 player.play()
 var audible=player.playing
 var mixing=AudioServer.get_bus_peak_volume_left_db(0,0)
 print('EXPORTED_AUDIO ', 'PASS' if audible else 'FAIL',' ambient plays through the audio server (bus peak %.1f dB)'%mixing)
 failed=failed or not audible
 # Stop and release before exiting, or the AudioStreamPlayback stays referenced and the
 # engine reports "1 resources still in use at exit".
 player.stop()
 player.stream=null
 player.queue_free()
 await host.get_tree().process_frame
 await host.get_tree().process_frame
 # Camouflage textures the class menu and the first-person sleeves load by name.
 for key in TEAM_CAMO:
  var path='res://assets/textures/camo_'+key+'_albedo.jpg'
  var texture=load(path)
  print('EXPORTED_RESOURCE ', 'PASS' if texture is Texture2D else 'FAIL',' ',path)
  failed=failed or not (texture is Texture2D)
 # Every first-person set and soldier the match can load.
 for kind in Arsenal.WEAPONS.size():
  var ok=FPSetRig.available(kind)
  print('EXPORTED_MODEL ', 'PASS' if ok else 'FAIL',' first-person set ',kind)
  failed=failed or not ok
 for team in ['aegis','ember']:
  var ok=ResourceLoader.exists('res://assets/characters/soldier_'+team+'.glb')
  print('EXPORTED_MODEL ', 'PASS' if ok else 'FAIL',' soldier ',team)
  failed=failed or not ok
 print('EXPORTED_ASSETS ', 'FAIL' if failed else 'PASS')
 host.get_tree().quit(1 if failed else 0)
