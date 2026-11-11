extends Node
## Capturas del menu principal y sus pantallas (cuenta local de prueba). Uso: MENU_OUT=/tmp/menu xvfb-run -a godot
## --display-driver x11 --rendering-driver opengl3 --resolution 1280x720 --path . res://tools/online/menu_snap.tscn

func _ready() -> void:
	var out: String = OS.get_environment("MENU_OUT") if OS.get_environment("MENU_OUT") != "" else "/tmp/menu"
	DirAccess.make_dir_recursive_absolute(out)
	var o: Node = get_node("/root/Online")
	o.use_local("user://menu_snap")
	await o.sign_up("snap%d@futbol.com" % randi(), "golazo123")
	await o.call_state_fn("create_profile", {"p_username": "Snap%d" % (randi() % 1000), "p_display_name": "Pibe Diez"})
	var m: MainMenu = (load(MainMenu.SCENE) as PackedScene).instantiate()
	add_child(m)
	for i in 120:
		await get_tree().process_frame
	await _shot(out + "/menu.png")
	for s in [["online", m.screens.open_online], ["tienda", m.screens.open_shop], ["temporada", m.screens.open_season],
			["eventos", m.screens.open_events], ["perfil", m.screens.open_profile], ["personalizar", m.screens.open_customize]]:
		s[1].call()
		for i in 40:
			await get_tree().process_frame
		await _shot("%s/%s.png" % [out, s[0]])
		m.screens.close()
	get_tree().quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("captura: ", path)
