extends SceneTree
var game: Node3D
var directory=ProjectSettings.globalize_path('res://build/screenshots-v2')
func _initialize():call_deferred('run')
func frame(name: String):
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(directory+'/'+name+'.png')
 print('SCREENSHOT ',name)
func run():
 DirAccess.make_dir_recursive_absolute(directory)
 game=load('res://main.tscn').instantiate();root.add_child(game)
 await create_timer(.35).timeout
 await frame('menu')
 game.showcase=true;game.start_match(false)
 var p=game.player;p.position=Vector3(0,.1,-15);p.yaw=PI-.10
 await create_timer(.45).timeout
 await frame('combat')
 Input.action_press('ads');await create_timer(.25).timeout
 await frame('ads')
 Input.action_release('ads');p.ammo[0]=12;p.start_reload()
 await create_timer(.50).timeout
 for f in game.fighters:f.set_physics_process(false)
 p.reload_left=Arsenal.WEAPONS[0].reload*.78*.55;p.view.update(p,.016)
 await frame('reload')
 p.weapon_id=2;p.build_gun();p.ads=true;p.reload_left=0
 for i in range(30):p.view.update(p,.016)
 p.camera.fov=46.8
 await frame('scope')
 game.hud.visible=false;game.menu_camera.position=Vector3(28,20,30);game.menu_camera.look_at(Vector3(0,1,0));game.menu_camera.current=true
 await frame('foundry')
 quit()
