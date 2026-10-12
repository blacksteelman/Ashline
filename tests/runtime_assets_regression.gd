extends SceneTree
# Existence check for resources that scripts load at runtime (a load() call is never
# seen by the exporter, so an excluded file only fails in a build).
const PATHS=[
 'res://assets/smoke.png','res://assets/muzzle.png','res://assets/ambient.wav',
 'res://assets/reload.wav','res://assets/step.wav','res://assets/hit.wav','res://assets/kill.wav',
 'res://assets/explosion.wav','res://assets/mag_out.wav','res://assets/mag_in.wav','res://assets/bolt.wav',
 'res://assets/impact_metal.wav','res://assets/impact_concrete.wav','res://assets/ricochet.wav',
 'res://assets/step_concrete.wav','res://assets/step_metal.wav','res://assets/dryfire.wav','res://assets/impact_body.wav',
 'res://assets/fx/bullet_hole.png','res://assets/fx/spark.png',
 'res://assets/fx/muzzle_front_0.png','res://assets/fx/muzzle_front_1.png','res://assets/fx/muzzle_front_2.png',
 'res://assets/fx/muzzle_side_0.png','res://assets/fx/muzzle_side_1.png','res://assets/fx/muzzle_side_2.png',
 'res://assets/interface.ttf','res://assets/mono.ttf',
 'res://assets/textures/camo_ocp_albedo.jpg','res://assets/textures/camo_emr_albedo.jpg','res://assets/textures/camo_mm14_albedo.jpg',
 'res://assets/shaders/viewmodel.gdshader','res://assets/shaders/viewmodel_glass.gdshader',
 'res://assets/shaders/viewmodel_fx.gdshader','res://assets/shaders/surface.gdshader',
 'res://assets/shaders/road_paint.gdshader','res://assets/shaders/facade_weathering.gdshader',
 'res://scripts/bolt_modifier.gd','res://scripts/hud.gd','res://scripts/frontend.gd','res://scripts/domination.gd',
]
func _initialize():call_deferred("run")
func run():
 var missing=[]
 for path in PATHS:
  if not ResourceLoader.exists(path):missing.append(path)
 print('RUNTIME ASSETS missing=',missing.size(),missing)
 # Weapons: every set and every third-person bake the game can pick.
 for kind in range(Arsenal.WEAPONS.size()):
  if not FPSetRig.available(kind):missing.append('fp set %d'%kind)
  var cfg='res://assets/viewmodels/world_'+Arsenal.WEAPONS[kind].fp.set
  if not ResourceLoader.exists(cfg+'.res'):missing.append(cfg+'.res')
  # data files are read with ConfigFile, not through the resource loader
  if not FileAccess.file_exists(cfg+'.cfg'):missing.append(cfg+'.cfg')
 for team in [0,1]:
  if not ResourceLoader.exists('res://assets/characters/soldier_'+['aegis','ember'][team]+'.glb'):missing.append('soldier %d'%team)
 print('CHECK_ASSETS ',('OK' if missing.is_empty() else 'MISSING '+str(missing)))
 quit(0 if missing.is_empty() else 1)
