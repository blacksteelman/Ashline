extends SceneTree
# Loads every runtime path (menu, class previews, both teams, every weapon first/third person) so an
# strace of this run lists the imported files the game uses (tools/export_filter.py).
func _initialize():call_deferred('run')
func frames(n):
 for i in range(n):await process_frame
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g)
 await frames(30)
 for team in [0,1]:
  g.start_match(false);await frames(30)
  var p=g.player;p.team=team
  for w in range(Arsenal.WEAPONS.size()):
   p.weapon_id=w;p.build_gun();p.update_world_weapon();await frames(5)
   p.ads=true;await frames(5);p.ads=false;p.shoot();await frames(5)
  for f in g.fighters:f.update_world_weapon()
  await frames(60)
  g.leave_match();await frames(20)
 print('TOUCH_DONE')
 quit()
