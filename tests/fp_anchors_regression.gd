extends SceneTree
var failures=0
var checks=0
func expect(ok: bool, label: String):
 checks+=1
 print('PASS ' if ok else 'FAIL ',label)
 if not ok:failures+=1
func _initialize():call_deferred('run')
func run():
 for kind in Arsenal.WEAPONS.size():
  var gun=load(FPSetRig.path(kind)).instantiate();root.add_child(gun)
  var rig=FPSetRig.new();rig.bind(gun,kind)
  var name=Arsenal.WEAPONS[kind].name
  expect(rig.cam_bone>=0 or rig.cfg.get('camera_anchor','')=='rig_origin',name+' declares a valid camera anchor')
  expect(rig.weapon_bone>=0,name+' has its weapon joint')
  for action in ['idle','fire','reload']:
   expect(rig.has_clip(action),name+' provides '+action)
   if rig.has_clip(action):
    rig.player.play(rig.clips[action]);rig.player.advance(.1)
    rig.skeleton.force_update_all_bone_transforms()
    expect(rig.camera_in_root().is_finite(),name+' camera pose stays finite in '+action)
  if kind==2:
   expect(rig.cam_bone==-1 and rig.camera_in_root().is_equal_approx(rig.skeleton_in_root()),'Sniper uses the authored rig-origin frame without an invalid bone lookup')
  var camera=rig.camera_in_root();camera.basis=camera.basis.orthonormalized()*rig.view_fix
  var align=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*rig.cfg.get('scale',1.0)),Vector3.ZERO)*FPSetRig.eye_fix(rig.cfg).affine_inverse()*camera.affine_inverse()
  var barrel=align*rig.bone_in_root(rig.weapon_bone)*rig.cfg.frame
  var sight=FPSetRig.ads_offset(rig.cfg,barrel)*barrel
  var rear=sight*rig.cfg.rear;var front=sight*rig.cfg.front
  expect(Vector2(rear.x,rear.y).length()<.0001 and Vector2(front.x,front.y).length()<.0001 and absf(rear.z+rig.cfg.eye)<.0001,name+' hip framing preserves the ADS sight line')
  gun.queue_free();await process_frame
 print('FP_ANCHORS ',checks,' checks, ',failures,' failures')
 quit(0 if failures==0 else 1)
