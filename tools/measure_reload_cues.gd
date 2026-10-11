extends SceneTree
# Reproduce FPSetRig.RELOAD_CUES from the real imported magazine tracks.
# godot --headless --path . --script tools/measure_reload_cues.gd
func _initialize():call_deferred('run')
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g);g.start_match(false)
 g.set_process(false);g.set_physics_process(false)
 for f in g.fighters:f.set_process(false);f.set_physics_process(false)
 var p=g.player
 for kind in 5:
  p.weapon_id=kind;p.build_gun();var rig=p.view
  for role in ['reload','reload_empty']:
   if not rig.clips.has(role):continue
   rig.player.play(rig.clips[role],0);rig.player.advance(0);rig.player.seek(0,true)
   var mag=-1
   for b in rig.skeleton.get_bone_count():
    if (rig.skeleton.get_bone_name(b).begins_with('Pmag_') or rig.skeleton.get_bone_name(b).begins_with('Mag_')) and not '_end' in rig.skeleton.get_bone_name(b):mag=b;break
   if mag<0:continue
   var rest=rig.bone_in_root(rig.weapon_bone).affine_inverse()*rig.bone_in_root(mag).origin
   var points=[]
   for i in 101:
    rig.player.seek(rig.player.get_animation(rig.clips[role]).length*i/100.0,true)
    var pos=rig.bone_in_root(rig.weapon_bone).affine_inverse()*rig.bone_in_root(mag).origin
    points.append(snappedf(pos.distance_to(rest)*rig.cfg.get('scale',1),.001))
   var first=-1;var last=-1
   for i in points.size():
    if points[i]>.015:
     if first<0:first=i
     last=i
   print('CUES ',kind,' ',role,' OUT=',first/100.0,' IN=',(last+1)/100.0)
 g.queue_free();await process_frame;await process_frame;quit()
