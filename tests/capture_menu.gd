extends SceneTree
# Menu screens: build/screenshots-v8/menu_main.png, menu_classes.png
func _initialize():call_deferred('run')
func frames(n):
 for i in range(n):await process_frame
func shot(name):
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://build/screenshots-v8/menu_'+name+'.png'));print('SHOT ',name)
func run():
 var g=load('res://main.tscn').instantiate();root.add_child(g)
 await frames(30);await shot('main')
 g.class_menu();await frames(10);await shot('classes')
 quit()
