extends Node
## Capturas de los menus con render (revision visual): menu principal, Personalizar, arcade con miniaturas, online.
## Usa un backend local en una carpeta temporal (no toca la cuenta del usuario).
## MENU_OUT=<prefijo> xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --resolution 1600x720 \
##   --path . res://tools/ui/menu_capture.tscn

func _shot(name: String) -> void:
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out: String = OS.get_environment("MENU_OUT")
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, name])
	print("captura: ", name)

func _ready() -> void:
	Online.use_local(OS.get_environment("MENU_OUT").get_base_dir().path_join("menu_capture_backend"))
	var r: Dictionary = await Online.sign_up("captura@futbol.com", "golazo123")
	if not r.get("ok", false):
		r = await Online.sign_in("captura@futbol.com", "golazo123")
	await Online.call_state_fn("create_profile", {"p_username": "Captura_10", "p_display_name": "Captura"})
	var menu: Node = (load("res://scenes/setpiece/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	for i in 40:
		await get_tree().process_frame
	await _shot("menu")
	var screens: MenuScreens = menu.get("screens")
	screens.open_customize()
	for i in 30:
		await get_tree().process_frame
	# Un diseño a rayas con segundo color, para ver los diseños sobre el cuerpo.
	for it in screens._items_of("jersey"):
		if String(it["name"]).to_lower().contains("rayas") and String(it["unlock"]) == "free":
			screens._set_appearance("jersey", String(it["id"]))
	screens._set_appearance("jersey_color2", 2)
	screens._show_custom_tab("jersey")
	await _shot("personalizar_camiseta")
	screens._show_custom_tab("body")
	await _shot("personalizar_cuerpo")
	screens.close()
	screens.open_online()
	for i in 30:
		await get_tree().process_frame
	await _shot("online")
	screens.close()
	screens.open_offline()
	await _shot("offline")
	menu.queue_free()
	ChallengeMenu.section = "arcade"
	ChallengeMenu.arcade_category = ""
	ChallengeMenu.arcade_item = ""
	var cm: Node = (load(ChallengeMenu.SCENE) as PackedScene).instantiate()
	add_child(cm)
	await _shot("arcade_categorias")
	ChallengeMenu.arcade_category = "habilidad"
	cm.call("_refresh")
	await _shot("arcade_habilidad")
	get_tree().quit()
