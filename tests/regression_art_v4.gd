extends SceneTree
var failures=0
func _initialize():call_deferred('run')
func check(value: bool, message: String):
 print(('PASS: ' if value else 'FAIL: ')+message)
 if not value:failures+=1
func ray(a: Vector3,b: Vector3) -> Dictionary:
 return root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
func run():
 var game=load('res://main.tscn').instantiate();root.add_child(game)
 await physics_frame;await physics_frame
 check(ray(Vector3(-17,3,-23.5),Vector3(-14,3,-23.5)).is_empty(),'Window opening admits bullets through physical wall')
 check(not ray(Vector3(-17,1.5,-23.5),Vector3(-14,1.5,-23.5)).is_empty(),'Window sill wall retains physical cover')
 check(not ray(Vector3(-17,3,-25.425),Vector3(-14,3,-25.425)).is_empty(),'Window jamb retains physical cover')
 var gun=Art.weapon(game,1)
 var skeletons=gun.find_children('*','Skeleton3D',true,false)
 check(skeletons.size()>=2,'Both first-person gloves have deforming skeletons')
 var player=gun.find_child('AnimationPlayer',true,false)
 var clip=''
 if player:
  for name in player.get_animation_list():
   if 'SupportHand_reload_contact' in name:clip=name
 check(not clip.is_empty(),'Support hand reload contact animation survives GLB export')
 if not clip.is_empty():
  player.play(clip);player.seek(.5,true);player.pause()
 check(gun.find_child('MagazineRig',true,false)!=null,'Curved magazine retains reload animation pivot')
 game.showcase=true;game.start_match(false)
 var p=game.player;var previous=p.gun
 p.weapon_id=3;p.build_gun()
 check(previous.get_parent()==null and not previous.visible,'Weapon switch removes old viewmodel before the next render')
 p.weapon_id=1;p.build_gun();p.start_reload();p.reload_left*=.5;p.view.update(p,.016)
 var rest_arm: Transform3D=p.view.rest[p.view.sleeve.get_instance_id()]
 var shift=p.view.support.position-p.view.rest[p.view.support.get_instance_id()].origin
 var wrist=Vector3(-.067,-.066,-.213)+shift
 var length=Vector3(-.067,-.066,-.213).distance_to(rest_arm.origin)
 var forearm_end=p.view.sleeve.position+p.view.sleeve.basis.y*length
 check(forearm_end.distance_to(wrist)<.002,'Reload keeps forearm attached to the wrist')
 var flash=Node3D.new();game.add_child(flash);game.add_fx(flash,.035)
 game.update_fx(.25)
 check(game.fx.any(func(effect):return effect.node==flash),'Short flash survives its first slow presentation frame')
 game.update_fx(.25)
 check(not game.fx.any(func(effect):return effect.node==flash),'Expired flash is removed after presentation')
 print('ART_REGRESSION_V4 failures=',failures)
 quit(1 if failures else 0)
