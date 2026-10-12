extends RefCounted
# Runs inside the exported executable; editor-only tests cannot catch missing raw CFGs.
static func run(host: Node3D):
 var failed=false
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
  weapon.free()
 print('EXPORTED_ASSETS ', 'FAIL' if failed else 'PASS')
 host.get_tree().quit(1 if failed else 0)
