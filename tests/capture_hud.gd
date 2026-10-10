extends SceneTree
# HUD check: a match frame with a filled kill feed, low ammo, a hit marker and the minimap.
# DISPLAY=:99 godot --path . --resolution 1280x720 --script tests/capture_hud.gd -- [--mode=dom]
func _initialize():call_deferred('run')
func frames(n):
 for i in range(n):await process_frame
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(false)
 for f in g.fighters:
  if not f.local_player:f.set_physics_process(false)
 await frames(40)
 var p=g.player
 g.feed=[{'killer':'SABLE','victim':'SLATE','head':true,'team':0,'time':4.0},{'killer':'ROOK','victim':'BRACE','head':false,'team':1,'time':4.0},{'killer':'DUSK','victim':'VEX','head':false,'team':0,'time':4.0}]
 g.scores=[23,19];p.ammo[p.weapon_id]=4;p.streak=2
 g.hit_time=.3;g.kill_time=.8;g.kill_zone='HEAD'
 await frames(2);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://build/screenshots-v8/hud.png'));print('SHOT hud')
 quit()
