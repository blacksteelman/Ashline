extends SceneTree
# Fixed idle pose, identical lighting and HUD state for before/after art review.
func _initialize():call_deferred('run')
func frames(n):
 for i in n:await process_frame
func run():
 var tag='review'
 for a in OS.get_cmdline_user_args():
  if a.begins_with('--tag='):tag=a.substr(6)
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(false)
 g.set_physics_process(false);g.set_process(false)
 for f in g.fighters:f.set_physics_process(false)
 var p=g.player
 var views=[[0,Vector3(-22,3.15,18.3),Vector3(-17.2,4,14.8)],
  [0,Vector3(1.5,.18,-30),Vector3(1.5,1.4,0)],
  [4,Vector3(1.5,.18,-30),Vector3(1.5,1.4,0)],
  [3,Vector3(-22,3.15,18.3),Vector3(-17.2,4,14.8)],
  [1,Vector3(1.5,.18,-30),Vector3(1.5,1.4,0)],
  [0,Vector3(1.5,.18,-30),Vector3(1.5,1.4,0)]]
 var folder='res://build/material-captures'
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 for i in views.size():
  p.set_process(true);p.weapon_id=views[i][0];p.build_gun()
  p.global_position=views[i][1];p.rotation.y=0
  var d=views[i][2]-(p.global_position+Vector3(0,1.62,0))
  p.yaw=atan2(-d.x,-d.z);p.pitch=atan2(d.y,Vector2(d.x,d.z).length())
  await frames(3)
  var rig=p.view
  rig.action='';rig.action_time=0;rig.equip_blend=1;rig.aim_blend=0
  rig.player.play(rig.clips.idle,0);rig.player.seek(.25,true);rig.player.advance(0);rig.player.pause()
  rig.update(p,0)
  p.set_process(false)
  g.scores=[23,19];g.time_left=413;g.feed=[];p.streak=2
  if i==5:
   p.ammo[0]=4;p.grenades=0;p.health=28;p.rewards=[3]
   g.hit_time=.3;g.kill_time=.8;g.kill_zone='HEAD'
   g.feed=[{'killer':'SABLE','victim':'SLATE','head':true,'team':0,'time':4.0},
    {'killer':'ROOK','victim':'BRACE','head':false,'team':1,'time':4.0}]
  await frames(3);await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder+'/%s-%d.png'%[tag,i]))
  print('MATERIAL SHOT ',i)
 quit()
